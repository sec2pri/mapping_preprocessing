[Github Action](https://github.com/sec2pri/mapping_preprocessing/blob/main/.github/workflows/wikidata.yml)

# Wikidata Metabolites and Gene/Protein SPARQL-query Processing

This repository contains instructions for processing the Wikidata SPARQL queries. The data is accessed through the Qlever SPARQL endpoint, which provides a faster query service. The Primary ID, potential Secondary ID, Name, and Aliases/Synonyms are downloaded in one query for metabolites and one query for genes and proteins.

## Steps
1. Download the data as CSVs (queries are located in folder 'datasources/wikidata/queries'):
```bash
##Add folder to store data in
mkdir datasources/wikidata/recentData/

## Download outdated IDs for chemicals qLever Style
curl -H "Accept: text/tab-separated-values" --data-urlencode query@datasources/wikidata/queries/chemicalAllRedirects.rq -G https://qlever.cs.uni-freiburg.de/api/wikidata -o datasources/wikidata/recentData/metabolites_secID2priID_qlever.tsv
## Download outdated IDs for genes and proteins qLever Style
curl -H "Accept: text/tab-separated-values" --data-urlencode query@datasources/wikidata/queries/geneproteinHumanAllRedirects.rq -G https://qlever.cs.uni-freiburg.de/api/wikidata -o datasources/wikidata/recentData/geneProtein_secID2priID_qlever.tsv
```
2. Check if the files are not empty
```bash
fail_file=''
for File in *.tsv ##Only for tsv files
  do
    if grep -q TimeoutException "$File"; then
      echo "Query Timeout occurred for file: " "$File" 
      echo "Wikidata data will not be updated"
      head -n 20 "$File" 
      fail_file="${fail_file} $File"
    else
      echo "No Query Timeout detected for file: " "$File" 
    fi
  done
```
3. Remove the IRIs for easier mappings to datasets
```bash
## Set prefix to Wikidata for renaming new data files
prefix=$(basename "Wikidata") 
## Data processing
cd datasources/wikidata/recentData

for f in *.tsv ##Only for tsv files
do
  ##Find all new data files | Remove the IRIs (prefix) | remove the IRIs (suffix) | remove language annotation | save the file with new name
  cat "$f" | sed 's/<http:\/\/www.wikidata.org\/entity\///g' | sed 's/[>]//g' | sed 's/@en//g' > "${prefix}_$f"
  rm "$f"
done
```




## Previous data download through Wikidata Query Service:

Wikidata updates their data throughout the day, and does not include release version.
Three queries have been constructued, for both the metabolite and chemical compound IDs, and for the gene/protein IDs:

- Redirects (Sec2Prim mappings)
- All Primary (to check for existing mappings)
- Primary synonyms (to find alterntaive names or symbols).

## Steps

1. Download the Wikidata data as CSV:
```bash
## Download outdated IDs for chemicals
curl -H "Accept: text/csv" --data-urlencode query@datasources/Wikidata/queries/chemicalRedirects.rq -G https://query.wikidata.org/sparql -o datasources/Wikidata/data/chemicalRedirectsWikidata.csv
## Download all primary IDs for chemicals
curl -H "Accept: text/csv" --data-urlencode query@datasources/Wikidata/queries/chemicalAllPrimary.rq -G https://query.wikidata.org/sparql -o datasources/Wikidata/data/chemicalAllPrimaryWikidata.csv
## Download alias/synonyms/names for chemicals
curl -H "Accept: text/csv" --data-urlencode query@datasources/Wikidata/queries/chemicalPrimarySynonyms.rq -G https://query.wikidata.org/sparql -o datasources/Wikidata/data/chemicalPrimarySynonymsWikidata.csv
          
## Download outdated IDs for genes and proteins
curl -H "Accept: text/csv" --data-urlencode query@datasources/Wikidata/queries/geneproteinHumanRedirects.rq -G https://query.wikidata.org/sparql -o datasources/Wikidata/data/geneproteinHumanRedirectsWikidata.csv
## Download all primary IDs for genes and proteins
curl -H "Accept: text/csv" --data-urlencode query@datasources/Wikidata/queries/geneproteinHumanAllPrimary.rq -G https://query.wikidata.org/sparql -o datasources/Wikidata/data/geneproteinHumanAllPrimaryWikidata.csv
```

2. Save the data (note that files above 100 MB need [LFS tracking](https://docs.github.com/en/repositories/working-with-files/managing-large-files/about-git-large-file-storage)
```bash
git pull
          git lfs track "geneproteinHumanRedirectsWikidata.csv"
          git lfs track "geneproteinHumanAllPrimaryWikidata.csv"
          git add .
          git config --local user.email "action@github.com"
          git config --local user.name "GitHub Action"
          git commit -m "Updating Wd data"
          git push
```
