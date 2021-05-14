####################################################################################
# Set the input folder
# Path to fasta file
# Path to bam folder
bam_folder="/data/felipelv/fcd-deep-wes/germline/bam/"

# Path to blood-only vcf
blood_only_folder="/data/felipelv/fcd-deep-wes/somatic/data/blood_only_vcf/"

 # Path to genomicsdb_workspace_path
genomicsdb_workspace_path="/data/felipelv/fcd-deep-wes/PON/"
####################################################################################
# Set path to gatk
gatk_path="/home/felipelv/tools/gatk-4.2.0.0/gatk"

# Set path to temporary script
tmp_script="/data/felipelv/fcd-deep-wes/somatic/data/mutec2.tmp.sh"
####################################################################################
# Set the input files
# Path to study design file
study_design_file="/data/felipelv/fcd-deep-wes/somatic/study.design.txt"

# set reference genome
ref_genome="/data/felipelv/fcd-deep-wes/somatic/data/ref/b37_hg19/Homo_sapiens_assembly19.fasta"

# Interval file without padding
interval_file_no_padding="/data/felipelv/fcd-deep-wes/somatic/data/S07604514_Regions.b37.interval_list"

# Interval file with padding
interval_file_with_padding="/data/felipelv/fcd-deep-wes/somatic/data/S07604514_Padded.b37.interval_list"

####################################################################################
# Start CPU iterators
cpu_it_1=1
cpu_it_2=2

# Step 1. Run Mutect2 in tumor-only mode for each normal sample.
 cat $study_design_file | grep "blood" |  awk '{if($8=="VERDADEIRO"){print $1}}' | sort -u | while read patient_id
do
	# Take blood and samples id
	blood_sample_id=$(cat $study_design_file | grep "blood" | awk -v patient_id=$patient_id '{if($1==patient_id){print $3}}'  )

	# Print the blood samples
	echo $blood_sample_id

	# Run mutec2 on blood samples
	echo "taskset --cpu-list "$cpu_it_1","$cpu_it_2" $gatk_path Mutect2 -R $ref_genome -I $bam_folder"/"$blood_sample_id".b37.bam -max-mnp-distance 0 -output "$blood_only_folder"/"$blood_sample_id".b37.vcf >$tmp_script

	# Increment CPU counts
	cpu_it_1=$(echo $cpu_it_1 | awk '{print $1+1}')
	cpu_it_2=$(echo $cpu_it_2 | awk '{print $1+1}')

	# Give permission to execute tmp script with mutec2 call
	chmod a+x $tmp_script 

	# Execute script in the background
	$tmp_script &

done
###########################
# Checkpoint Step 1
echo "Step 1 Successfully done"
###########################

#Step 2. Create a GenomicsDB from the normal Mutect2 calls.
# First concatenate a string with the name of all bam files
str_normal_vcf_file_cmd=$(ls $bam_folder | grep ".bam" | sed ':a;N;$!ba;s/\n/ -V /g' | awk '{print "-V "$0}')

# Then call GenomicsDBImport (interval_file_no_padding + --interval-padding 100)
$gatk_path Mutect2 GenomicsDBImport -R $ref_genome -L $interval_file_no_padding --genomicsdb-workspace-path $genomicsdb_workspace_path $str_normal_vcf_file_cmd --interval-padding 100

###########################
# Checkpoint Step 2
echo "Step 2 Successfully done"
###########################
# Step 3. Combine the normal calls using CreateSomaticPanelOfNormals.
$gatk_path CreateSomaticPanelOfNormals -R $ref_genome -V $genomicsdb_workspace_path -O $genomicsdb_workspace_path$"pon.fcd.blood.vcf.gz"
###########################
# Checkpoint Step 3
echo "Step 3 Successfully done"
###########################
