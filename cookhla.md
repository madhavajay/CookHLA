# How to use CookHLA

CookHLA imputes HLA alleles from SNP genotype data in the MHC region. It expects
PLINK binary input and SNP2HLA-style reference panels.

## What CookHLA takes as input

CookHLA input must be a PLINK binary prefix:

```text
PREFIX.bed
PREFIX.bim
PREFIX.fam
```

You pass only the prefix:

```bash
python CookHLA.py -i PREFIX ...
```

CookHLA does not directly take raw 23andMe, Ancestry, Dynamic DNA, or other
direct-to-consumer text files. Convert those to PLINK binary first.

CookHLA only uses the MHC region on chromosome 6, roughly:

```text
chr6:29-34 Mb
```

## Genome build

Most CookHLA/SNP2HLA-style reference panels are hg18 / NCBI Build 36.

If your input is another build, tell CookHLA with `-hg`:

```bash
-hg 18    # hg18 / Build 36
-hg 19    # hg19 / GRCh37
-hg 38    # hg38 / GRCh38
```

For GRCh38 input, CookHLA liftover is:

```text
hg38 -> hg19 -> hg18
```

The `.bim` positions must match the build you declare with `-hg`.

## Reference panels included in this repo

This checkout includes reference panel data in the repo, not from a Python
package:

```text
example/      small example panel, about 2.7 MB
1000G_REF/    1000 Genomes panels, about 170 MB
```

Examples:

```text
example/HM_CEU_REF
1000G_REF/1000G_REF.ALL.chr6.hg18.29mb-34mb.inT1DGC
1000G_REF/1000G_REF.EUR.chr6.hg18.29mb-34mb.inT1DGC
1000G_REF/1000G_REF.AFR.chr6.hg18.29mb-34mb.inT1DGC
1000G_REF/1000G_REF.AMR.chr6.hg18.29mb-34mb.inT1DGC
1000G_REF/1000G_REF.EAS.chr6.hg18.29mb-34mb.inT1DGC
1000G_REF/1000G_REF.SAS.chr6.hg18.29mb-34mb.inT1DGC
```

Each reference is passed as a prefix, without file extensions.

## Convert a raw SNP text file to PLINK

For a DTC-style tab-delimited file with columns like:

```text
rsid    chromosome    position    genotype
```

Create a strict chr6 four-column file:

```bash
mkdir -p work/carika

awk 'BEGIN{FS=OFS="\t"; print "# rsid\tchromosome\tposition\tgenotype"}
  !/^#/ && $2==6 && $4 ~ /^[ACGT][ACGT]$/ {
    id=$1
    if (id=="." || id=="") id="chr"$2"_"$3
    print id,$2,$3,$4
  }' /path/to/raw_genotypes.txt > work/carika/input.chr6.txt
```

Convert to PLINK binary:

```bash
plink --23file work/carika/input.chr6.txt \
  --make-bed \
  --out work/carika/input_chr6
```

This creates:

```text
work/carika/input_chr6.bed
work/carika/input_chr6.bim
work/carika/input_chr6.fam
```

## Run CookHLA

Example using GRCh38 input and the bundled example CEU reference:

```bash
python CookHLA.py \
  -i work/carika/input_chr6 \
  -hg 38 \
  -o work/carika/input_HM_CEU_REF \
  -ref example/HM_CEU_REF \
  -gm example/AGM.1958BC+HM_CEU_REF.mach_step.avg.clpsB \
  -ae example/AGM.1958BC+HM_CEU_REF.aver.erate \
  -mem 2g
```

If using the local Apple Silicon environment created during this run:

```bash
PATH=/Users/madhavajay/micromamba/envs/CookHLA-arm/bin:$PATH \
  /Users/madhavajay/micromamba/envs/CookHLA-arm/bin/python CookHLA.py \
  -i work/carika/input_chr6 \
  -hg 38 \
  -o work/carika/input_HM_CEU_REF \
  -ref example/HM_CEU_REF \
  -gm example/AGM.1958BC+HM_CEU_REF.mach_step.avg.clpsB \
  -ae example/AGM.1958BC+HM_CEU_REF.aver.erate \
  -mem 2g
```

## Output files

The main result file is:

```text
OUTPUT_PREFIX.MHC.HLA_IMPUTATION_OUT.alleles
```

The HPED-format output is:

```text
OUTPUT_PREFIX.MHC.HLA_IMPUTATION_OUT.hped
```

The `.alleles` file has no header by default. Columns are:

```text
family_id
individual_id
hla_gene
broad_2_digit_call
specific_4_digit_call
allele_1_posterior
allele_2_posterior
combined_posterior
```

Pipeline schema:

| Column | Name | Meaning |
| --- | --- | --- |
| 1 | `family_id` | PLINK family ID from the `.fam` file |
| 2 | `individual_id` | PLINK individual ID from the `.fam` file |
| 3 | `hla_gene` | HLA gene, e.g. `A`, `B`, `C`, `DQA1`, `DQB1`, `DRB1` |
| 4 | `broad_2_digit_call` | Pair of broad allele groups, e.g. `68,03` means `A*68 / A*03` |
| 5 | `specific_4_digit_call` | Pair of two-field alleles, e.g. `6801,0301` means `A*68:01 / A*03:01` |
| 6 | `allele_1_posterior` | Posterior probability for allele 1 |
| 7 | `allele_2_posterior` | Posterior probability for allele 2 |
| 8 | `combined_posterior` | Confidence score for the genotype call |

Example:

```text
ID001 ID001 A 68,03 6801,0301 0.501672240802676 0.376254180602007 0.877926421404683
```

Meaning:

```text
sample:       ID001
gene:         HLA-A
2-digit:      A*68 / A*03
4-digit:      A*68:01 / A*03:01
confidence:   posterior probabilities for allele 1, allele 2, and combined call
```

The `combined_posterior` is CookHLA's confidence score:

- for a heterozygous call, it is the sum of posterior probabilities for the two called alleles
- for a homozygous call, it is the posterior probability of that allele

Use this as a ranking/filtering metric in downstream aggregation. Lower values
mean the imputed call is less certain. There is no universal cutoff that fits
every study; keep the raw posterior columns so later analysis can apply its own
threshold.

## Create a headed result table

After CookHLA finishes, create a readable tab-delimited table:

```bash
awk 'BEGIN{
    OFS="\t"
    print "family_id","individual_id","hla_gene","broad_2_digit_call","specific_4_digit_call","allele_1","allele_2","allele_1_posterior","allele_2_posterior","combined_posterior"
  }
  function fmt(g,a){
    if (a=="" || a=="0") return "0"
    return g "*" substr(a,1,length(a)-2) ":" substr(a,length(a)-1,2)
  }
  {
    split($5,a,",")
    allele1=fmt($3,a[1])
    allele2=fmt($3,a[2])
    print $1,$2,$3,$4,$5,allele1,allele2,$6,$7,$8
  }' OUTPUT_PREFIX.MHC.HLA_IMPUTATION_OUT.alleles > OUTPUT_PREFIX.HLA_results_with_headers.txt
```

Recommended pipeline output columns:

```text
run_id
family_id
individual_id
hla_gene
broad_2_digit_call
specific_4_digit_call
allele_1
allele_2
allele_1_posterior
allele_2_posterior
combined_posterior
reference_panel
input_build
output_prefix
```

## Aggregate multiple CookHLA results

If each sample/run has one CookHLA `.alleles` file, aggregate them into one
tab-delimited table like this:

```bash
printf '%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\n' \
  run_id family_id individual_id hla_gene broad_2_digit_call specific_4_digit_call \
  allele_1 allele_2 allele_1_posterior allele_2_posterior combined_posterior \
  reference_panel input_build output_prefix > all_HLA_results.tsv

for f in work/*/*.MHC.HLA_IMPUTATION_OUT.alleles; do
  prefix="${f%.MHC.HLA_IMPUTATION_OUT.alleles}"
  run_id="$(basename "$prefix")"
  awk -v run_id="$run_id" \
      -v reference_panel="example/HM_CEU_REF" \
      -v input_build="hg38" \
      -v output_prefix="$prefix" '
    BEGIN{OFS="\t"}
    function fmt(g,a){
      if (a=="" || a=="0") return "0"
      return g "*" substr(a,1,length(a)-2) ":" substr(a,length(a)-1,2)
    }
    {
      split($5,a,",")
      allele1=fmt($3,a[1])
      allele2=fmt($3,a[2])
      print run_id,$1,$2,$3,$4,$5,allele1,allele2,$6,$7,$8,reference_panel,input_build,output_prefix
    }' "$f" >> all_HLA_results.tsv
done
```

For this run, the result file was:

```text
work/carika/carika_HM_CEU_REF.MHC.HLA_IMPUTATION_OUT.alleles
```

The headed table created from it was:

```text
work/carika/carika_HLA_results_with_headers.txt
```

## Interpreting aggregated output

Each individual should normally have one row per imputed HLA gene. With the
bundled example reference, this run returned:

```text
A
B
C
DQA1
DQB1
DRB1
```

Some genes may be absent depending on the reference panel, QC, and imputation
result. Do not assume every panel emits every HLA gene; aggregate by
`individual_id + hla_gene` and preserve missingness.

Useful downstream derived fields:

```text
is_homozygous = allele_1 == allele_2
low_confidence = combined_posterior < chosen_threshold
allele_1_gene_prefixed = allele_1
allele_2_gene_prefixed = allele_2
```

Example interpretation:

```text
HLA-A  A*68:01 / A*03:01  combined_posterior=0.8779
```

This is an imputed heterozygous HLA-A call. The broad call is `A*68 / A*03`,
the two-field call is `A*68:01 / A*03:01`, and the combined confidence score is
about `0.878`.

## Docker

There is a public Docker Hub image:

```bash
docker pull dhkwnr97/cookhla:v1.0.1
```

Docker Hub lists it as `linux/amd64`. This local repo does not include a
Dockerfile upstream, but this branch adds one.

Build the local image:

```bash
docker build --platform linux/amd64 -t cookhla:madhava-docker .
```

This branch also includes GitHub Actions CI in:

```text
.github/workflows/docker.yml
```

On push to `madhava/docker`, `master`, or `main`, CI builds a `linux/amd64`
image and pushes it to GHCR:

```text
ghcr.io/madhavajay/cookhla:madhava-docker
ghcr.io/madhavajay/cookhla:sha-<commit>
```

Run CookHLA from the image:

```bash
docker run --rm \
  -v "$PWD/work:/work" \
  cookhla:madhava-docker \
  -i /work/carika/input_chr6 \
  -hg 38 \
  -o /work/carika/input_HM_CEU_REF \
  -ref example/HM_CEU_REF \
  -gm example/AGM.1958BC+HM_CEU_REF.mach_step.avg.clpsB \
  -ae example/AGM.1958BC+HM_CEU_REF.aver.erate \
  -mem 2g
```

The image includes the repo's bundled panel data:

```text
/opt/CookHLA/example
/opt/CookHLA/1000G_REF
/opt/CookHLA/dependency
```

It also bakes in UCSC liftover chains needed for GRCh38 input:

```text
/opt/CookHLA/work/chains/hg38ToHg19.over.chain.gz
/opt/CookHLA/work/chains/hg19ToHg18.over.chain.gz
```

## Notes

HLA calls from CookHLA are imputed predictions from SNP data, not direct HLA
typing. Treat confidence values as important, especially for low or borderline
posterior probabilities.
