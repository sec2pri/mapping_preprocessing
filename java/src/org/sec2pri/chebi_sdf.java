package org.sec2pri;

import java.io.BufferedReader;
import java.io.FileReader;
import java.io.IOException;
import java.sql.SQLException;
import java.util.*;
import org.bridgedb.DataSource;
import org.bridgedb.IDMapperException;
import org.bridgedb.rdb.construct.GdbConstruct;
import java.io.FileWriter;
import java.io.File;
import java.text.SimpleDateFormat;
import org.bridgedb.Xref;
import org.bridgedb.bio.DataSourceTxt;
import org.bridgedb.rdb.construct.DBConnector;
import org.bridgedb.rdb.construct.DataDerby;
import org.bridgedb.rdb.construct.GdbConstructImpl4;

/**
 * Mapping the secondary identifiers (retired or withdrawn identifies) to primary identifiers (currently used identifiers).
 * 
 * @author tabbassidaloii
 */

public class chebi_sdf {
	public static String sourceName = "ChEBI"; //ChEBI
	public static String sourceIdCode = "Ce"; //Ce
	public static String sourceSynonymCode = "O"; //O
	public static String DbVersion = "1";
	public static String BridgeDbVersion = "3.0.28";
	private static DataSource dsId;
	private static DataSource dsSynonym;
	private static GdbConstruct newDb;
	
	public static void main(String[] args) throws IOException, IDMapperException, SQLException {
		//Assign the input argument to the corresponding variables
		File inputFile = new File(args[0]);
		setupDatasources();
		File outputDir = new File(args[1]);
		outputDir.mkdir();

		//Create output bridge mapping file
		File outputFile = new File(outputDir, sourceName + "_secID2priID.bridge");
		
		try {
			createDb(outputFile);
			} catch (IDMapperException e1) {
				e1.printStackTrace();
				}
		
		//Create output tsv mapping files
		////primary ID
		List<List<String>> listOfpri = new ArrayList<>(); //list of primary IDs
		////Secondary to primary ID
		List<List<String>> listOfsec2pri = new ArrayList<>(); //list of the secondary to primary IDs
		////name to synonyms
		List<List<String>> listOfname2synonym = new ArrayList<>(); //list of the name to synonym 

		
		try (BufferedReader file = new BufferedReader(new FileReader(inputFile))) {
			String dataRow = file.readLine();
			String priId = "";
			String secId = "";
			String name = "";
			String syn = "";
			
			//create tsv file with all the ChEBI IDs
	        List<String> pri= new ArrayList<String>(); 
			pri.add("primaryID");
			//create tsv mapping file for sec2pri ID
	        List<String> sec2pri= new ArrayList<String>(); 
			sec2pri.add("primaryID");
			sec2pri.add("\t");
			sec2pri.add("secondaryID");
			//create tsv mapping file for name2synonyms
	        List<String> name2synonym= new ArrayList<String>(); 
	        name2synonym.add("primaryID");
	        name2synonym.add("\t");
	        name2synonym.add("name");
	        name2synonym.add("\t");
	        name2synonym.add("synonym");
	        
		    //create BridgeDb mapping file
		    Map<Xref, Set<Xref>> map = new HashMap<Xref, Set<Xref>>();
			int counter = 0;
			int counter2 = 0;
			
			while (dataRow != null) {
				boolean priLine = dataRow.startsWith("> <ChEBI ID>");
				if (priLine) {//extract row with primary identifier
					counter++;
					if(!pri.isEmpty()) listOfpri.add(pri);
					pri = new ArrayList<>();
					if(!sec2pri.isEmpty()) listOfsec2pri.add(sec2pri);
					sec2pri = new ArrayList<>();
					if(!name2synonym.isEmpty()) listOfname2synonym.add(name2synonym);
					name2synonym = new ArrayList<>();
					dataRow = file.readLine();
					priId = dataRow;
					pri.add(priId);
					}
				Xref priId_B2B = new Xref(priId, dsId);
				map.put(priId_B2B, new HashSet<Xref>());

				if (dataRow.startsWith("> <ChEBI Name>")) {
					dataRow = file.readLine();//extract row with metabolite name
					name = dataRow;
					}
				Xref Synonym_B2B = new Xref(name, dsSynonym);
				map.get(priId_B2B).add(Synonym_B2B);
				

				boolean secLine = dataRow.startsWith("> <Secondary ChEBI ID>");
				if (secLine) {//extract rows with secondary identifiers
					dataRow = file.readLine();
					secId = dataRow;
					Xref secId_B2B_1 = new Xref(secId, dsId, false); //the first column is the secondary id so idPrimary = false
					map.get(priId_B2B).add(secId_B2B_1);
					sec2pri.add(priId);
					sec2pri.add("\t");
					sec2pri.add(secId);

					dataRow = file.readLine();
					while (dataRow.startsWith("CHEBI:")) {
						secId = dataRow;
						sec2pri.add("\n");
						sec2pri.add(priId);
						sec2pri.add("\t");
						sec2pri.add(secId);
						Xref secId_B2B_2 = new Xref(secId, dsId, false); //the first column is the secondary id so idPrimary = false
						map.get(priId_B2B).add(secId_B2B_2);
						dataRow = file.readLine();
						}
					}
				
				boolean synLine = dataRow.startsWith("> <Synonyms>");
				if (synLine) {//extract rows with synonyms
					dataRow = file.readLine();
					syn = dataRow;
					
					if (dataRow == null && dataRow.isEmpty()) {
						name2synonym.add(priId);
						name2synonym.add("\t");
						name2synonym.add(name);
						name2synonym.add("\t");
					} else {
						name2synonym.add(priId);
						name2synonym.add("\t");
						name2synonym.add(name);
						name2synonym.add("\t");
						name2synonym.add(syn);
					}

					dataRow = file.readLine();
					while (dataRow != null && !dataRow.isEmpty()) {
						syn = dataRow;
						name2synonym.add("\n");
						name2synonym.add(priId);
						name2synonym.add("\t");
						name2synonym.add(name);
						name2synonym.add("\t");
						name2synonym.add(syn);
						dataRow = file.readLine();
						}
					}

				dataRow = file.readLine();
				if (counter == 5000) {
					counter2++;
					System.out.println("5k mark " + counter2 + ": " + priId);
					counter = 0;
					addEntries(map);
					map.clear();
					// finished = true;
					}
				}
	
			File output_pri_Tsv = new File(outputDir, sourceName + "_priIDs.tsv");
			FileWriter writer_pri = new FileWriter(output_pri_Tsv); 
			for (int i = 0; i < listOfpri.stream().count(); i++) {
				List<String> list = listOfpri.get(i);
				for (String str:list) {
					writer_pri.write(str);
					}
				writer_pri.write(System.lineSeparator());
			}
			writer_pri.close();
			System.out.println("[INFO]: List of primary IDs is written");
			
			File output_sec2pri_Tsv = new File(outputDir, sourceName + "_secID2priID.tsv");
			FileWriter writer = new FileWriter(output_sec2pri_Tsv); 
			for (int i = 0; i < listOfsec2pri.stream().count(); i++) {
				List<String> list = listOfsec2pri.get(i);
				for (String str:list) {
					writer.write(str);
					}
				writer.write(System.lineSeparator());
			}
			writer.close();
			System.out.println("[INFO]: Secondary to primary id table is written");
			
			File output_name_Tsv = new File(outputDir, sourceName + "_name2synonym.tsv");
			FileWriter writer_name = new FileWriter(output_name_Tsv); 
			for (int i = 0; i < listOfname2synonym.stream().count(); i++) {
				List<String> list = listOfname2synonym.get(i);
				for (String str:list) {
					writer_name.write(str);
					}
				writer_name.write(System.lineSeparator());
			}
			writer_name.close();
			System.out.println("[INFO]: Name to synonyms table is written");
			System.out.println("Start to the creation of the derby database, might take some time");
			addEntries(map);
			file.close();	
			}
		newDb.finalize();
		System.out.println("[INFO]: Database finished.");
		System.out.println(new Date());
		}
	
	private static void createDb(File outputFile) throws IDMapperException {
		newDb = new GdbConstructImpl4(outputFile.getAbsolutePath(),new DataDerby(), DBConnector.PROP_RECREATE);
		newDb.createGdbTables();
		newDb.preInsert();
			
		String dateStr = new SimpleDateFormat("yyyyMMdd").format(new Date());
		newDb.setInfo("BUILDDATE", dateStr);
		newDb.setInfo("DATASOURCENAME", chebi_sdf.sourceName);
		newDb.setInfo("DATASOURCEVERSION", DbVersion);
		newDb.setInfo("BRIDGEDBVERSION", BridgeDbVersion);
		newDb.setInfo("DATATYPE", "Identifiers");	
		}
	
	private static void setupDatasources() {
		DataSourceTxt.init();
		dsId = DataSource.getExistingBySystemCode(chebi_sdf.sourceIdCode);
		dsSynonym = DataSource.getExistingBySystemCode(chebi_sdf.sourceSynonymCode);
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
