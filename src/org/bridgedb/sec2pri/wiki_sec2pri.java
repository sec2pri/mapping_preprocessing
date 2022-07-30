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
import java.sql.SQLException;
import org.bridgedb.DataSource;
import org.bridgedb.IDMapperException;
import org.bridgedb.rdb.construct.GdbConstruct;
import java.text.SimpleDateFormat;
import java.util.Date;
import java.util.HashMap;
import java.util.HashSet;
import java.util.Map;
import java.util.Set;
import org.bridgedb.Xref;
import org.bridgedb.bio.DataSourceTxt;
import org.bridgedb.rdb.construct.DBConnector;
import org.bridgedb.rdb.construct.DataDerby;
import org.bridgedb.rdb.construct.GdbConstructImpl4;

public class wiki_sec2pri {
	public static String sourceName = ""; //wikidata
	public static String sourceIdCode = ""; //Wd
	public static String DbVersion = "1.0.0";
	public static String BridgeDbVersion = "3.0.13";
	private static DataSource dsId; 
	private static GdbConstruct newDb;
	
	public static void main(String[] args) throws IOException, IDMapperException, SQLException {
		wiki_sec2pri.sourceName = args[0]; //datasource   
		wiki_sec2pri.sourceIdCode = args[1]; //datasource code
		setupDatasources();

		File outputDir = new File("output");
		outputDir.mkdir(); // creating output directory if not exit
		File outputTsv = new File(outputDir, sourceName + "_secIds.tsv"); //tsv output file
		File outputFile = new File(outputDir, sourceName + "_secIds.bridge"); //bridgeDb output file
		createDb(outputFile);
		
		List<List<String>> listOfsec2pri = new ArrayList<>(); //list to save secondary to primary IDs
        List<String> sec2pri= new ArrayList<String>(); 
		sec2pri.add("primaryID");
		sec2pri.add(",");
		sec2pri.add("secondaryID");

		
		//Wikidata for metabolites
		String sparqlEndpoint = "https://query.wikidata.org/sparql"; 
	    SPARQLRepository repo = new SPARQLRepository(sparqlEndpoint);

	    String userAgent = "Wikidata RDF4J Java Example/0.1 (https://query.wikidata.org/)";
	    repo.setAdditionalHttpHeaders(Collections.singletonMap("User-Agent", userAgent));
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
	    Map<Xref, Set<Xref>> map = new HashMap<Xref, Set<Xref>>();
	    
	    try (TupleQueryResult result = sparqlQuery.evaluate()) {
	    	for (BindingSet solution:result) {//parsing the results to save each mapping in proper formant
	    		sparqlQuery.setBinding("row", solution.getValue("row"));
	    		if(!sec2pri.isEmpty()) listOfsec2pri.add(sec2pri);
	    		sec2pri = new ArrayList<>();
	    		sec2pri.add(solution.toString().replace("[primary=http://www.wikidata.org/entity/", "")
	    				.replace("secondary=http://www.wikidata.org/entity/", "")
	    				.replace(";", ",")
	    				.replace("]", ""));
	    		
	    		String priId = sec2pri.toString().replace("[","").replaceFirst(",.*", "");
	    		Xref priId_B2B = new Xref(priId, dsId);
				map.put(priId_B2B, new HashSet<Xref>());
				String secId = sec2pri.toString().replace("]","").replaceFirst(".*,", "");
				Xref secId_B2B = new Xref(secId, dsId, false); //the first column is the secondary id so idPrimary = false
				map.get(priId_B2B).add(secId_B2B);
	    		}
	    	}
	    	    
		FileWriter writer = new FileWriter(outputTsv); //writting the tsv file 
		for (int i = 0; i < listOfsec2pri.stream().count(); i++) {
			List<String> list = listOfsec2pri.get(i);
			for (String str:list) {
				writer.write(str);
				}
			writer.write(System.lineSeparator());
			}
		writer.close();
		System.out.println("[INFO]: Secondary to primary id table is written");
		
		addEntries(map);
		newDb.finalize();
		System.out.println("[INFO]: Database finished.");
		
		}

	private static void createDb(File outputFile) throws IDMapperException {
		newDb = new GdbConstructImpl4(outputFile.getAbsolutePath(),new DataDerby(), DBConnector.PROP_RECREATE);
		newDb.createGdbTables();
		newDb.preInsert();
		
			
		String dateStr = new SimpleDateFormat("yyyyMMdd").format(new Date());
		newDb.setInfo("BUILDDATE", dateStr);
		newDb.setInfo("DATASOURCENAME", wiki_sec2pri.sourceName);
		
		newDb.setInfo("DATASOURCEVERSION", DbVersion);
		newDb.setInfo("BRIDGEDBVERSION", BridgeDbVersion);
		newDb.setInfo("DATATYPE", "Identifiers");	
		}
	
	
	private static void setupDatasources() {
		DataSourceTxt.init();
		dsId = DataSource.getExistingBySystemCode(wiki_sec2pri.sourceIdCode);
		}
	
	private static void addEntries(Map<Xref, Set<Xref>> dbEntries) throws IDMapperException {
		Set<Xref> addedXrefs = new HashSet<Xref>();
		for (Xref ref : dbEntries.keySet()) {
			Xref mainXref = ref;
			if (addedXrefs.add(mainXref)) newDb.addGene(mainXref);
			newDb.addLink(mainXref, mainXref);

			for (Xref rightXref : dbEntries.get(mainXref)) {
				if (!rightXref.equals(mainXref) && rightXref != null) {
					if (addedXrefs.add(rightXref)) newDb.addGene(rightXref);
					newDb.addLink(mainXref, rightXref);
					}
				}
			newDb.commit();
			}
		}
	}
