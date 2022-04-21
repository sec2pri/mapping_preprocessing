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
import java.io.IOException;
//import java.nio.charset.Charset;
//import java.nio.charset.StandardCharsets;
//import java.nio.file.Files;
//import java.nio.file.Paths;
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
import org.bridgedb.rdb.construct.GdbConstructImpl3;
//import org.bridgedb.tools.qc.BridgeQC;

/**
 * Mapping the secondary identifiers (retired or withdrawn identifies) to primary identifiers (currently used identifiers).
 * 
 * @author mkutmon
 * @author egonw
 * @author tabbassidaloii
 */
public class sec2pri {

	public static String sourceName = "";
	public static String sourceCode = "";
	public static String DbVersion = "1.0.0";
	public static String BridgeDbVersion = "3.0.13";
	private static DataSource dsPriId;
	private static DataSource dsSecId;
	private static GdbConstruct newDb;
	
	public static void main(String[] args) throws IOException, IDMapperException, SQLException {
		sec2pri.sourceName = args[0];  
		sec2pri.sourceCode = args[2];  
		
		setupDatasources();
		File outputDir = new File("output");
		outputDir.mkdir();
		File outputFile = new File(outputDir, sourceName + ".bridge");
		createDb(outputFile);
		File inputDir = new File("input");
		BufferedReader file = new BufferedReader(new FileReader(inputDir + "/" + sourceName + ".csv"));
        String dataRow = file.readLine(); // skip the first line
        dataRow = file.readLine();

        Map<Xref, Set<Xref>> map = new HashMap<Xref, Set<Xref>>();
		int counter = 0;
		int counter2 = 0;
		boolean finished = false;
        while (dataRow != null && !finished) {
        	//the input for separator e.g. '\t'
        	String splitChar = args[1]; 
        	String[] fields = dataRow.split(splitChar);
        	String identifier = fields[0].replaceAll("\"", "");
			Xref secId = new Xref(identifier, dsSecId, false); //the first column is the secondary id so idPrimary = false
			map.put(secId, new HashSet<Xref>());

			
			if (fields.length > 1) {
				String priId = fields[1].replaceAll("\"", "");
				Xref priIdRef = new Xref(priId, dsPriId);
				map.get(secId).add(priIdRef);
				//System.out.println(priIdRef);
			}
			dataRow = file.readLine();
			counter++;
			if (counter == 5000) {
				counter2++;
				System.out.println("5k mark " + counter2 + ": " + secId);
				counter = 0;
				addEntries(map);
				map.clear();
				// finished = true;
			}
		}
		addEntries(map);
		newDb.finalize();
		file.close();
		System.out.println("[INFO]: Database finished.");
	}
	
	private static void createDb(File outputFile) throws IDMapperException {
			
		newDb = new GdbConstructImpl3(outputFile.getAbsolutePath(),new DataDerby(), DBConnector.PROP_RECREATE);
		newDb.createGdbTables();
		newDb.preInsert();
		
			
		String dateStr = new SimpleDateFormat("yyyyMMdd").format(new Date());
		newDb.setInfo("BUILDDATE", dateStr);
		newDb.setInfo("DATASOURCENAME", sec2pri.sourceName);
		
		newDb.setInfo("DATASOURCEVERSION", DbVersion);
		newDb.setInfo("BRIDGEDBVERSION", BridgeDbVersion);
		newDb.setInfo("DATATYPE", "Identifiers");	

	}
	
	private static void setupDatasources() {
		DataSourceTxt.init();
		dsPriId = DataSource.getExistingBySystemCode(sec2pri.sourceCode);
		dsSecId = DataSource.getExistingBySystemCode(sec2pri.sourceCode);
	}

	private static void addEntries(Map<Xref, Set<Xref>> dbEntries) throws IDMapperException {
		Set<Xref> addedXrefs = new HashSet<Xref>();
		for (Xref ref : dbEntries.keySet()) {
			Xref mainXref = ref;
			//System.out.println("mainXref: " + mainXref.isPrimary());

			if (addedXrefs.add(mainXref)) newDb.addGene(mainXref);
			newDb.addLink(mainXref, mainXref);

			for (Xref rightXref : dbEntries.get(mainXref)) {
				if (!rightXref.equals(mainXref) && rightXref != null) {
					if (addedXrefs.add(rightXref)) newDb.addGene(rightXref);
					//System.out.println("rightXref: " + rightXref.isPrimary());

					newDb.addLink(mainXref, rightXref);
				}
			}
			// System.out.println("[INFO]: Commit " + mainXref);
			newDb.commit();
		}
	}

}


