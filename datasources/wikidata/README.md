[Github Action](https://github.com/sec2pri/mapping_preprocessing/blob/main/.github/workflows/wikidata.yml)

# Wikidata Metabolites and Gene/Protein SPARQL-query Processing

This repository contains instructions for processing the Wikidata SPARQL queries. Wikidata updated their data throughout the day, and does not include release version.
Three queries have been constructued, for both the metabolite and chemical compound IDs, and for the gene/protein IDs:

TODO: add queries from Qlever.
Move content below to previous version running on Wikidata

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
