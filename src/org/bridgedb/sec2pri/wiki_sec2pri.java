package org.bridgedb.sec2pri;


import org.eclipse.rdf4j.query.BindingSet;
import org.eclipse.rdf4j.query.TupleQuery;
import org.eclipse.rdf4j.query.TupleQueryResult;
import org.eclipse.rdf4j.repository.sparql.SPARQLRepository;
import java.io.File;
import java.io.FileWriter;
import java.io.IOException;
import java.util.ArrayList;
import java.util.Collections;
import java.util.List;

/**
* Wikidata for metabolites
*/
public class wiki_sec2pri {
	public static String sourceName = "wikidata"; //wikidata
	
	public static void main( String[] args ) throws IOException	{
		File outputDir = new File("output");
		outputDir.mkdir();

		List<List<String>> listOfsec2pri = new ArrayList<>(); //list of the secondary to primary IDs
        List<String> sec2pri= new ArrayList<String>(); 
		sec2pri.add("primaryID");
		sec2pri.add(",");
		sec2pri.add("secondaryID");

		String sparqlEndpoint = "https://query.wikidata.org/sparql";
	    SPARQLRepository repo = new SPARQLRepository(sparqlEndpoint);

	    String userAgent = "Wikidata RDF4J Java Example/0.1 (https://query.wikidata.org/)";
	    repo.setAdditionalHttpHeaders( Collections.singletonMap("User-Agent", userAgent ) );

	    String querySelect = "#Redirect\n" +
	    "SELECT ?primary ?secondary WITH {\n" +
	    "  SELECT ?primary\n" +
	    "WHERE \n" +
	    "{  \n" +
	    "    { ?primary p:P31/ps:P31 wd:Q11173 }\n" +
	    "    UNION\n" +
	    "    { ?primary p:P31/ps:P31 wd:Q36496 }\n" +
	    "    UNION\n" +
	    "    { ?primary p:P31/ps:P31 wd:Q79529 }\n" +
	    "    UNION\n" +
	    "    { ?primary p:P31/ps:P31 wd:Q55662747 }\n" +
	    "    UNION\n" +
	    "    { ?primary p:P279/ps:P279 wd:Q11173 }\n" +
	    "    UNION\n" +
	    "    { ?primary p:P279/ps:P279 wd:Q36496 }\n" +
	    "    UNION\n" +
	    "    { ?primary p:P279/ps:P279 wd:Q79529 }\n" +
	    "    UNION\n" +
	    "    { ?primary p:P279/ps:P279 wd:Q55662747 }\n" +
	    "  }\n" +
	    "} AS %RESULTS {\n" +
	    "  INCLUDE %RESULTS\n" +
	    " \n" +
	    "  ?secondary owl:sameAs ?primary. # redirect\n" +
	    "}";
	    
	     
	    TupleQuery sparqlQuery = repo.getConnection().prepareTupleQuery(querySelect);
	    try (TupleQueryResult result = sparqlQuery.evaluate()) {
	    	for (BindingSet solution:result) {
	    		sparqlQuery.setBinding("row", solution.getValue("row"));
	    		if(!sec2pri.isEmpty()) listOfsec2pri.add(sec2pri);
	    		sec2pri = new ArrayList<>();
	    		sec2pri.add(solution.toString().replace("[primary=http://www.wikidata.org/entity/", "")
	    				.replace("secondary=http://www.wikidata.org/entity/", "")
	    				.replace(";", ",")
	    				.replace("]", ""));
	    		}
	    	}
	    	    
		File outputTsv = new File(outputDir, sourceName + "_secIds.tsv");
		FileWriter writer = new FileWriter(outputTsv); 
		for (int i = 0; i < listOfsec2pri.stream().count(); i++) {
			List<String> list = listOfsec2pri.get(i);
			for (String str:list) {
				writer.write(str);
				}
			writer.write(System.lineSeparator());
			}
		writer.close();
		System.out.println("[INFO]: Secondary to primary id table is written");
		}
	}