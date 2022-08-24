##############################
###   cfDNA pipeline v2    ###
### Author: Adrienne Chang ###
###   Created: 8/22/2022   ###
##############################

import os
import pandas as pd
from natsort import natsorted
import itertools

### Updating the metagenomic database ###
# A new metagenomic database will only be created if
# 	(1) MAKE_NEWDB is set to "TRUE", and
# 	(2) A new file "add_assembly_accession.txt" is created.
# 	    The new file should contain a single column of assembly accessions (i.e. GCF_002287175.1).
# 	    This can be obtained from the first column of the assembly_summary.txt file downloaded
# 	    from ftp://ftp.ncbi.nlm.nih.gov/, and
# 	(3) A NEWDB_NAME is set
MAKE_NEWDB = "FALSE"
NEWDB_NAME = "NCBIGenomes22_test"


### CHANGE ONLY IF USING NCBIGENOMES06 ###
### CANNOT BE USED WITH MAKE_NEWDB ###
OLD_MET_REF = "FALSE"

### CHANGE ONLY IF MAKING A NEW METHYLMATRIX ###
NEW_METHYL = "FALSE"
NEWMETH_NAME = "test"

#####################################
### DO NOT MODIFY BELOW THIS LINE ###
#####################################

### LOAD CONFIG ###
configfile: 'workflow/main.yaml'

MP = config['MASTER_PATH']
SEQ_PREP_TABLE = config['SEQ_PREP_TABLE']
METHYLOME_TABLE = config['METHYLOME_TABLE']
OUTPUT = config['OUTPUT']
GENOMES = config['GENOMES']
CHR = config['CHR']

# References
DATA = config['DATA']
HG19 = MP + config['HG19']
HG19_CHROMO_SIZES = MP + config['HG19_CHROMO_SIZES']
HG38 = MP + config['HG38']
HG38_CHROMO_SIZES = MP + config['HG38_CHROMO_SIZES']
PHIX = MP + config['PHIX']
HG19STD = MP + config['HG19STD']
HG19METH = MP + config['HG19METH']
HG38STD = MP + config['HG38STD']
HG38METH = MP + config['HG38METH']
PHIXSTD = MP + config['PHIXSTD']
PHIXMETH = MP + config['PHIXMETH']

REFERENCE_METHYLOMES = config['REFERENCE_METHYLOMES']

NCBI_06 = MP + config['NCBI_06']
GI_TAXID_06 = MP + config['GI_TAXID_06']
GI_LENGTH_06 = MP + config['GI_LENGTH_06']
GDT_06 = config['GDT_06']
LUT_06 = MP + config['LUT_06']

NCBI_22 = config['NCBI_22']
GI_TAXID_22 = config['GI_TAXID_22']
GI_LENGTH_22 = config['GI_LENGTH_22']
GDT_22 = config['GDT_22']
LUT_22 = config['LUT_22']
NCBI_CT = config['NCBI_CT']
NCBI_GA = config['NCBI_GA']
GDT_CT = config['GDT_CT']
GDT_GA = config['GDT_GA']
HUMAN_22 = MP + config['HUMAN_22']

GOLDENBED_HG19 = MP + config['GOLDENBED_HG19']
GOLDENBED_HG38 = MP + config['GOLDENBED_HG38']
METHYLMATRIX_HG19 = MP + config['METHYLMATRIX_HG19']
METHYLMATRIX_HG38 = MP + config['METHYLMATRIX_HG38']

CT_DECON = MP + config['CT_DECON']
GA_DECON = MP + config['GA_DECON']
BOTH_DECON = MP + config['BOTH_DECON']

SRSLY = MP + config['SRSLY']
MEYER = MP + config['MEYER']

CFSMOD1 = MP + config['CFSMOD1']
CFSMOD2 = MP + config['CFSMOD2']

# Scripts
AGGMETH = config['AGGMETH']
BPBED = config['BPBED']
RMDBL = config['RMDBL']
DL_GENOMES = config['DL_GENOMES']
REF_CONV = config['REF_CONV']
GENOMESIZE = config['GENOMESIZE']
MAKELUT = config['MAKELUT']
MERGELUT = config['MERGELUT']
FILTER_STRAND = config['FILTER_STRAND']
FILTER_STRAND_GI = config['FILTER_STRAND_GI']
COUNT_FASTQ = config['COUNT_FASTQ']
CALC_COV = config['CALC_COV']
NON_DUP = config['NON_DUP']
INTER = config['INTER']
ANN_GRAMMY_GI = config['ANN_GRAMMY_GI']
ANN_GRAMMY_ACC = config['ANN_GRAMMY_ACC']
SRA = config['SRA']
TOFAGG = config['TOFAGG']
TOF = config['TOF']
INSIL_CONV = config['INSIL_CONV']
FILTA = config['FILTA']
FILTB = config['FILTB']
CONSOLIDATE = config['CONSOLIDATE']

# Programs
ADD_STR = MP + config['ADD_STR']
F2S = MP + config['F2S']
S2F = MP + config['S2F']
TRANSPOSE = MP + config['TRANSPOSE']
FILTER = MP + config['FILTER']
ADD_COL = MP + config['ADD_COL']
HSBLASTN = MP + config['HSBLASTN']
GRAMMY_GDT = MP + config['GRAMMY_GDT']
GRAMMY_EM = MP + config['GRAMMY_EM']
GRAMMY_POST = MP + config['GRAMMY_POST']
GRAMMY_RDT = MP + config['GRAMMY_RDT']
GRAMMY_PRE_ACC = MP + config['GRAMMY_PRE_ACC']
GRAMMY_PRE_GI = MP + config['GRAMMY_PRE_GI']
BBDUK = MP + config['BBDUK']
BISMARK = MP + config['BISMARK']
BISDEDUP = MP + config['BISDEDUP']
METHEXT = MP + config['METHEXT']
RMDUPS = MP + config['RMDUPS']
METHPIPETOMR = MP + config['METHPIPETOMR']
METHPIPEBSRATE = MP + config['METHPIPEBSRATE']
DEDUP = MP + config['DEDUP']
CROSSMAP = MP + config['CROSSMAP']
METILENE = MP + config['METILENE']

### LOAD UNIVERSAL VARIABLES ###
sample_information  = pd.read_csv("sequencing_prep.tsv", index_col = 0, sep = "\t")

def get_project(sample): return(sample_information.loc[sample, "project_id"])
def get_fastq_path(sample): return(sample_information.loc[sample, "path"])
def get_prep_type(sample): return(sample_information.loc[sample,"seq_type"])

SAMPLES = sample_information.index.values
PROJECTS = list(set([get_project(s) for s in SAMPLES]))
samplesInProjects = {}
for p in PROJECTS:
    samplesInProjects[p] = sample_information.loc[sample_information.project_id == p].index.tolist()


def get_sample_info(wcrds):
    with open(SEQ_PREP_TABLE) as f:
        next(f)
        for line in f:
            sample_id, project_id, prep_type, path, genome_ver, seq_type = line.strip().split('\t')
        if str(wcrds.sample) == sample_id:
            return[sample_id, project_id, prep_type, path, genome_ver, seq_type]

### FUNCTIONS ###
def string_split(string,delimiter, number_of_splits):
    s=string.split(delimiter, number_of_splits)
    return(s)

tissues = natsorted(set(x.split('_')[0] for x in config['REFERENCE_METHYLOMES']))
comparing_groups=list(itertools.combinations(tissues,2))
comparing_groups=[x[0]+'_'+x[1] for x in comparing_groups]

### RULE SETS ###
MAKEREF = [expand('references/' + NEWDB_NAME + '/' + 'LUT/taxids_names_lengths_tax.tab', conversion=config['CONVERSION']),expand('references/' + NEWDB_NAME + '/{conversion}/' + NEWDB_NAME + '_{conversion}.gdt', conversion = config['CONVERSION'])]

MAKE_METHYL = [expand('references/reference_methylomes_' + NEWMETH_NAME + '/singleBP_bedGraph_{genome}/{methylome}.singlebp.bedGraph', comp_group = comparing_groups, methylome = config['REFERENCE_METHYLOMES'], genome=config['GENOMES'])]

 
#ANALYSIS = [ OUTPUT + '{project}/{sample}/{sample}.grammy.tab'.format(sample=sample, project=get_project(sample)) for sample in SAMPLES]


ANALYSIS = [ OUTPUT + '{project}/{sample}/{sample}.bsconversion'.format(sample=sample, project=get_project(sample)) for sample in SAMPLES]

if MAKE_NEWDB == "FALSE" and NEW_METHYL == "FALSE":
    inputs = ANALYSIS
elif MAKE_NEWDB == "TRUE" and NEW_METHYL == "FALSE":
    inputs = MAKEREF + ANALYSIS 
elif MAKE_NEWDB == "FALSE" and NEW_METHYL == "TRUE":
    inputs = MAKE_METHYL 
else:
    inputs =  MAKEREF + MAKE_METHYL + ANALYSIS

rule all:
	input: inputs


### CONDITION TO CONVERT .fastq TO _fastq ###
if (os.path.exists(DATA + '{project}/{sample}_R1.fastq.gz')):
	ruleorder: touch > fastqc
elif (os.path.exists(DATA + '{project}/{sample}.R1.fastq.gz')):
	ruleorder: rename > fastqc

### CONDITION TO MAKE NEW REF BEFORE BLAST ###
if MAKE_NEWDB == "TRUE":
    ruleorder: LUTfile > make_grammydb > hsblastn

### RULES TO GENERATE NEW METAGENOMIC DB ###
include: 'workflow/rules/make_reference.smk'

### RULES TO GENERATE NEW TOF DB ###
include: 'workflow/rules/reference_methylomes/download_methylomes.smk'
include: 'workflow/rules/reference_methylomes/format_methylomes.smk'
include: 'workflow/rules/reference_methylomes/create_methylmatrix.smk'
#include: 'workflow/rules/reference_methylomes/get_DMRs2.smk'

### RULES TO RUN SAMPLE ANALYSIS ###
include: 'workflow/rules/rename.smk'
include: 'workflow/rules/fastqc.smk'
include: 'workflow/rules/trim/trimmomatic.smk'
include: 'workflow/rules/merge.smk'
include: 'workflow/rules/alignment/bwa.smk'
include: 'workflow/rules/stats/align_stats.smk'
include: 'workflow/rules/metagenomic/hsblastn.smk'

### BISULFITE ONLY RULES ###
include: 'workflow/rules/trim/bbduk.smk'
include: 'workflow/rules/alignment/bismark.smk'
include: 'workflow/rules/methylation/estimate_BSconversion.smk'
include: 'workflow/rules/methylation/methylation_extraction.smk'
include: 'workflow/rules/methylation/tissues_of_origin.smk'
include: 'workflow/rules/metagenomic/decontaminate.smk'
#include: 'workflow/rules/metagenomic/C_poor_abundances.smk'
#include: 'workflow/rules/unfiltered_abundances.smk'