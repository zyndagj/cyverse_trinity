#!/bin/bash

function cleanup() {
	# Delete input files
	rm -f *{fasta,fa,fastq,fq,gz,bam}
	# Delete intermediate directories
	for f in trinity_out_dir/{chrysalis,insilico_read_normalization,read_partitions}; do [ -e $f ] && rm -rf $f; done
	# Delete both (input)
	for f in trinity_out_dir/{\.[a-zA-Z]*,both.fa,single.fa}; do [ -e $f ] && rm $f; done
	# Compress fasta files
	#\ls trinity_out_dir/*{fa,fasta,sam} | xargs -n 1 -P $NCORES gzip -4
	for f in trinity_out_dir/*{fa,fasta,sam}; do [ -e $f ] && echo $f; done | xargs -n 1 -P $NCORES gzip -4
	# Move assembly fasta to run directory
	target=trinity_out_dir/Trinity.fasta.gz; [ -e $target ] && mv $target .
	# Tar Trinity directory
	[ -e trinity_out_dir ] && ( tar -cf trinity_out_dir.tar trinity_out_dir && rm -rf trinity_out_dir )
}
# Format input files to have /1 and /2 in read names
function formatFile {
	# Arguments
	inFile=$1
	readIndex=$2
	tmpFile=tmp_${2}

	if [ ${inFile##*.} == "gz" ]; then
		# Input is gzipped
		readCmd="zcat $inFile"
		outCmd="gzip -4c - "
	else
		# Input is plaintext
		readCmd="cat $inFile"
		outCmd="cat - "
	fi
	# Get first line
	read1name=$( eval $readCmd | head -n 1 )
	if [[ ! $read1name == */${readIndex}* ]]; then
		# Incorrect format
		if [[ "${read1name:0:1}" == ">" ]]; then
			# Fasta file
			eval $readCmd | sed -e "s/^\(>[^ ]\+\).*/\1\/${readIndex}/" | eval $outCmd > $tmpFile
		else
			# Fastq file
			eval $readCmd | sed -e "1~2 s/^\([@+][^ ]\+\).*/\1\/${readIndex}/" | eval $outCmd > $tmpFile
		fi
		mv ${tmpFile} ${inFile}
	fi
}
export JAVABIN=$(which java)
function java {
	timeout 30m ${JAVABIN} $@;
}
export -f java

###############################################################
# Inputs
###############################################################
validI=""
function inputCheck() {
	if [ "$validI" == "true" ]; then
		validI=false
		echo -e "\n[ERROR] Do not mix input types\n" 1>&2
	fi
	[ -z "$validI" ] && validI=true
}
# Paired-end input
if [ -n "${left}" ] && [ -n "${right}" ]; then
	# Check read name formatting
	leftFile=$( echo "${left}" | cut -f 3 -d " " )
	rightFile=$( echo "${right}" | cut -f 3 -d " " )
	formatFile ${leftFile} 1 &
	formatFile ${rightFile} 2 &
	wait
	ARGS="${left}${right}"
	inputCheck
fi
# Handle single-end invocation
if [ -n "${single}" ]; then
	ARGS="${single}"
	inputCheck
fi
# Genome guided invocation
if [ -n "${genome_guided_bam}" ]; then
	ARGS="${genome_guided_bam}"
	inputCheck
	# GG parameters
	ARGS+="${gg_max_intron}${gg_min_coverage}${gg_min_reads_per_partition}"
fi

###############################################################
# Parameters
###############################################################

NCORES=$(nproc --all)
MAXMEM=$(grep MemTotal /proc/meminfo | awk '{print int($2*8.5/10/1000000)}')

ARGS+=" --CPU $NCORES --max_memory ${MAXMEM}G${SS_lib_type}${seqType}${KMER_SIZE}${min_contig_length}${group_pairs_distance}${min_kmer_cov}${trimmomatic}"

###############################################################
# Run
###############################################################

if [ "$validI" == "true" ]; then
	echo "Trinity ${ARGS}"
	Trinity ${ARGS}
fi
cleanup

# Matthew W. Vaughn, Ph.D.,
# Manager, Life Sciences Computing Group
# Texas Advanced Computing Center
# Austin, TX
# vaughn@tacc.utexas.edu | (949) 436-6642
# Ported to iPlant Agave API by Roger Barthelson rogerab@email.arizona.edu
# Updated by Greg Zynda - 2018
