/**
Copyright 2020 

Licensed under the Apache License, Version 2.0 (the "License");
you may not use this file except in compliance with the License.
You may obtain a copy of the License at

    http://www.apache.org/licenses/LICENSE-2.0

Unless required by applicable law or agreed to in writing, software
distributed under the License is distributed on an "AS IS" BASIS,
WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
See the License for the specific language governing permissions and
limitations under the License.
 **/
package org.bridgedb.sec2pri;

import java.io.BufferedReader;
import java.io.File;
import java.io.FileReader;
import java.io.FileWriter;
import java.io.IOException;
import java.sql.SQLException;
import java.text.SimpleDateFormat;
import java.util.Date;
import java.util.HashMap;
import java.util.HashSet;
import java.util.Map;
import java.util.Set;
import org.bridgedb.DataSource;
import org.bridgedb.IDMapperException;
import org.bridgedb.Xref;
import org.bridgedb.bio.DataSourceTxt;
import org.bridgedb.rdb.construct.DBConnector;
import org.bridgedb.rdb.construct.DataDerby;
import org.bridgedb.rdb.construct.GdbConstruct;
import org.bridgedb.rdb.construct.GdbConstructImpl4;

import java.util.ArrayList;
import java.util.Arrays;
import java.util.List;

/**
 * Mapping the secondary identifiers (retired or withdrawn identifies) to primary identifiers (currently used identifiers).
 * 
 * @author mkutmon
 * @author egonw
 * @author tabbassidaloii
 */
public class TXTsec2pri {

	public static String sourceName = "";
	public static String sourceIdCode = "";
	public static String sourceSymbolCode = "";
	public static String DbVersion = "1.0.0";
	public static String BridgeDbVersion = "3.0.13";
	private static DataSource dsId;
	private static DataSource dsSymbol;
	private static GdbConstruct newDb;
	
	public static void main(String[] args) throws IOException, IDMapperException, SQLException {
		TXTsec2pri.sourceName = args[0];  
		TXTsec2pri.sourceIdCode = args[1];  
		TXTsec2pri.sourceSymbolCode = args[2];  

		setupDatasources();
		File outputDir = new File("output");
		outputDir.mkdir();
		File outputFile = new File(outputDir, sourceName + "_secIds.bridge");
		createDb(outputFile);
		//Create output tsv mapping file
		List<List<String>> listOfsec2pri = new ArrayList<>(); //list of the secondary to primary IDs
		
		File inputDir = new File("input");
		BufferedReader file = new BufferedReader(new FileReader(inputDir + "/" + sourceName + ".csv"));
        String dataRow = file.readLine(); // skip the first line
        dataRow = file.readLine();

    	// creating tsv mapping file
        List<String> sec2pri= new ArrayList<String>(); 
		sec2pri.add("primaryID");
		sec2pri.add(",");
		sec2pri.add("secondaryID");
		sec2pri.add("\n");

		Map<Xref, Set<Xref>> map = new HashMap<Xref, Set<Xref>>();
		int counter = 0;
		int counter2 = 0;
		boolean finished = false;
        while (dataRow != null && !finished) {
        	//the input for separator e.g. '\t' ','
        	String splitChar = args[3]; 
        	String[] fields = dataRow.split(splitChar);

        	String identifier = fields[0].replaceAll("\"", "");
			Xref priId = new Xref(identifier, dsId);
			map.put(priId, new HashSet<Xref>());
			
			if (fields.length > 1) {
				if (!fields[1].replaceAll("\"", "").contentEquals("NA") & !fields[1].replaceAll("\"", "").isEmpty()) {
					String secIds = fields[1].replaceAll("\"", "");
					List<String> ArraySecIds = Arrays.asList(secIds.split("; "));
					for (String secId:ArraySecIds) { 
						Xref secIdRef = new Xref(secId, dsId, false); //the first column is the secondary id so idPrimary = false
						map.get(priId).add(secIdRef);

						sec2pri.add(identifier.replaceAll("\\..*$", ""));
						sec2pri.add(",");
						sec2pri.add(secId);
						//sec2pri.add("\n");
						// Add the list to list of listfor the secondary to primary id mapping in tsv
						listOfsec2pri.add(sec2pri);
						sec2pri = new ArrayList<>();

						}
					}
								
				if (fields.length > 2) {
					String priSymbols = fields[2].replaceAll("\"", "");
					List<String> ArrayPriSymbols = Arrays.asList(priSymbols.split("; "));
					for (String priSymbol:ArrayPriSymbols) { 
						Xref priSymbolRef = new Xref(priSymbol, dsSymbol);
						map.get(priId).add(priSymbolRef);
						}
					if (fields.length > 3) {
						String secSymbols = fields[3].replaceAll("\"", "");
						List<String> ArraySecSymbols = Arrays.asList(secSymbols.split("; "));
						for (String secSymbol:ArraySecSymbols) { 
							Xref secSymbolRef = new Xref(secSymbol, dsSymbol, false);  //the first column is the secondary id so idPrimary = false
							map.get(priId).add(secSymbolRef);
							}
						}
					}
				}
			
			dataRow = file.readLine();
			counter++;
			if (counter == 5000) {
				counter2++;
				System.out.println("5k mark " + counter2 + ": " + priId);
				counter = 0;
				addEntries(map);
				map.clear();
				// finished = true;
				}
			}
        
        addEntries(map);
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
	
        
		newDb.finalize();
		System.out.println("[INFO]: Database finished.");
		file.close();
	}
	
	private static void createDb(File outputFile) throws IDMapperException {
		newDb = new GdbConstructImpl4(outputFile.getAbsolutePath(),new DataDerby(), DBConnector.PROP_RECREATE);
		newDb.createGdbTables();
		newDb.preInsert();
		
			
		String dateStr = new SimpleDateFormat("yyyyMMdd").format(new Date());
		newDb.setInfo("BUILDDATE", dateStr);
		newDb.setInfo("DATASOURCENAME", TXTsec2pri.sourceName);
		
		newDb.setInfo("DATASOURCEVERSION", DbVersion);
		newDb.setInfo("BRIDGEDBVERSION", BridgeDbVersion);
		newDb.setInfo("DATATYPE", "Identifiers");	
		}
	
	
	private static void setupDatasources() {
		DataSourceTxt.init();
		dsId = DataSource.getExistingBySystemCode(TXTsec2pri.sourceIdCode);
		dsSymbol = DataSource.getExistingBySystemCode(TXTsec2pri.sourceSymbolCode);
		}
	
	private static void addEntries(Map<Xref, Set<Xref>> dbEntries) throws IDMapperException {
		Set<Xref> addedXrefs = new HashSet<Xref>();
		for (Xref ref : dbEntries.keySet()) {
			Xref mainXref = ref;
			if (addedXrefs.add(mainXref)) newDb.addGene(mainXref);
			newDb.addLink(mainXref, mainXref);

			for (Xref rightXref : dbEntries.get(mainXref)) {
			//	System.out.println("rightXref: " + rightXref);
			//	System.out.println("mainXref: " + mainXref);
			//	System.out.println("!rightXref.equals(mainXref): " + !rightXref.equals(mainXref));
			//	System.out.println("rightXref != null: " + rightXref != null);
			//	System.out.println("!rightXref.equals(mainXref) && rightXref != null: " + !rightXref.equals(mainXref) + rightXref != null);

				

				
				if (!rightXref.equals(mainXref) && rightXref != null) {
					if (addedXrefs.add(rightXref)) newDb.addGene(rightXref);
					newDb.addLink(mainXref, rightXref);
					}
				}
			newDb.commit();
			}
		}
	}



