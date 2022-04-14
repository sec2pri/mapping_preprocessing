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
import org.xml.sax.InputSource;

/**
 * Mapping the secondary identifiers (retired or withdrawn identifies) to primary identifiers (currently used identifiers).
 * 
 * @author mkutmon
 * @author egonw
 * @author tabbassidaloii
 */
public class sec2pri {

	public static String sourceName = "hgncID";
	public static String sourceCode = "H";
	private static DataSource daPriId;
	private static DataSource dsWhen;
	private static DataSource dsSecId;
	private static GdbConstruct newDb;
	
	public static void main(String[] args) throws IOException, IDMapperException, SQLException {
		String sourceName = args[0];  
		System.out.println(sourceName);
		String sourceCode = args[2];
		System.out.println(sourceCode);

		setupDatasources();
		File outputDir = new File("output");
		outputDir.mkdir();
		File outputFile = new File(outputDir, sourceName + ".bridge");
		createDb(outputFile);
		//File releasedDb = new File(outputDir, "publications_20200510.bridge");

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
			Xref secId = new Xref(identifier, dsSecId);
			map.put(secId, new HashSet<Xref>());
			//System.out.println(secId);

			
			if (fields.length > 1) {
				// no defined ExistingBySystemCode for date of the removal
				//String when = fields[1].replaceAll("\"", "");
				//Xref whenRef = new Xref(when, dsWhen); # 
				//map.get(secId).add(whenRef);	
				//System.out.println(whenRef);

				if (fields.length > 2) {
					String priId = fields[2].replaceAll("\"", "");
					Xref priIdRef = new Xref(priId, daPriId);
					map.get(secId).add(priIdRef);
					//System.out.println(priIdRef);
				}
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
		//runQC(releasedDb, outputFile);
	}
	
	private static void createDb(File outputFile) throws IDMapperException {
			
		newDb = new GdbConstructImpl3(outputFile.getAbsolutePath(),new DataDerby(), DBConnector.PROP_RECREATE);
		newDb.createGdbTables();
		newDb.preInsert();
		
			
		String dateStr = new SimpleDateFormat("yyyyMMdd").format(new Date());
		newDb.setInfo("BUILDDATE", dateStr);
		//String sourceName = args[0];  
		newDb.setInfo("DATASOURCENAME", sourceName);
		newDb.setInfo("DATASOURCEVERSION", "1.0.0");
		newDb.setInfo("BRIDGEDBVERSION", "3.0.13");
		newDb.setInfo("DATATYPE", "Identifiers");	

	}
	
	private static void setupDatasources() {
		DataSourceTxt.init();
		daPriId = DataSource.getExistingBySystemCode(sourceCode);
		dsWhen = DataSource.getExistingBySystemCode("O");
		dsSecId = DataSource.getExistingBySystemCode("O");
	}

	//private static String readQuery(String path) throws IOException {
	//	String content = readFile(path, StandardCharsets.UTF_8);
	//	return content;
	//}

	//private static String readFile(String path, Charset encoding) throws IOException {
	//	byte[] encoded = Files.readAllBytes(Paths.get(path));
	//	return new String(encoded, encoding);
	//}

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
			// System.out.println("[INFO]: Commit " + mainXref);
			newDb.commit();
		}
	}
	
	private static String[] inputSource(String[] args) throws IOException {
		String[] source = {args[0], args[1]};

		return (source);
	}

	
	//private static void runQC(File oldDB, File newDB) throws IDMapperException, SQLException{
	//	BridgeQC qc = new BridgeQC (oldDB, newDB);
	//	qc.run();
	//}
}


