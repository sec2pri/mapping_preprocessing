package org.bridgedb.sec2pri;
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
import java.util.List;

/**
 * Mapping the secondary identifiers (retired or withdrawn identifies) to primary identifiers (currently used identifiers).
 * 
 * @author tabbassidaloii
 */

public class SDFsec2pri {
	public static String sourceName = "";
	public static String sourceIdCode = "";
	public static String sourceSymbolCode = "";
	public static String DbVersion = "1.0.0";
	public static String BridgeDbVersion = "3.0.13";
	private static DataSource dsId;
	private static DataSource dsSymbol;
	private static GdbConstruct newDb;
	
	public static void main(String[] args) throws IOException, IDMapperException, SQLException {
		SDFsec2pri.sourceName = args[0];  
		SDFsec2pri.sourceIdCode = args[1];  
		SDFsec2pri.sourceSymbolCode = args[2];  
		setupDatasources();
		File outputDir = new File("output");
		outputDir.mkdir();
		File outputFile = new File(outputDir, sourceName + "_secIds.bridge");
		createDb(outputFile);
		File inputDir = new File("input");
		
		List<List<String>> listOfsec2pri = new ArrayList<>(); //list of the secondary to primary IDs
		try (BufferedReader file = new BufferedReader(new FileReader(inputDir + "/" + sourceName + "/" + "ChEBI_complete_3star.sdf"))) {
			String dataRow = file.readLine();
			String priId = "";
			String secId = "";
			// creating tsv mapping file
	        List<String> sec2pri= new ArrayList<String>(); 
			sec2pri.add("primaryID");
			sec2pri.add(",");
			sec2pri.add("secondaryID");
		    // creating BridgeDb mapping file
		    Map<Xref, Set<Xref>> map = new HashMap<Xref, Set<Xref>>();
			int counter = 0;
			int counter2 = 0;
			
			while (dataRow != null) {
				boolean priLine = dataRow.startsWith("> <ChEBI ID>");
				if (priLine) {//extracting row with primary identifier
					counter++;
					dataRow = file.readLine();
					if(!sec2pri.isEmpty()) listOfsec2pri.add(sec2pri);
					sec2pri = new ArrayList<>();
					priId = dataRow;
					sec2pri.add(priId);
					sec2pri.add(",");
					}
				Xref priId_B2B = new Xref(priId, dsId);
				map.put(priId_B2B, new HashSet<Xref>());
				
				if (dataRow.startsWith("> <ChEBI Name>")) {
					dataRow = file.readLine();//extracting row with metabolite name
					String name = dataRow;
					Xref Symbol_B2B = new Xref(name, dsSymbol);
					map.get(priId_B2B).add(Symbol_B2B);
					}
			
				boolean secLine = dataRow.startsWith("> <Secondary ChEBI ID>");
				if (secLine) {//extracting rows with secondary identifiers
					dataRow = file.readLine();
					secId = dataRow;
					sec2pri.add(secId);
					Xref secId_B2B_1 = new Xref(secId, dsId, false); //the first column is the secondary id so idPrimary = false
					map.get(priId_B2B).add(secId_B2B_1);
					dataRow = file.readLine();
					while (dataRow.startsWith("CHEBI:")) {
						secId = dataRow;
						//System.out.println("secId: " + secId);
						sec2pri.add("\n");
						sec2pri.add(priId);
						sec2pri.add(",");
						sec2pri.add(secId);
						Xref secId_B2B_2 = new Xref(secId, dsId, false); //the first column is the secondary id so idPrimary = false
						map.get(priId_B2B).add(secId_B2B_2);
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
			
			addEntries(map);
			newDb.finalize();
			System.out.println("[INFO]: Database finished.");
			file.close();
	
			}
		}
	private static void createDb(File outputFile) throws IDMapperException {
		newDb = new GdbConstructImpl4(outputFile.getAbsolutePath(),new DataDerby(), DBConnector.PROP_RECREATE);
		newDb.createGdbTables();
		newDb.preInsert();
		
			
		String dateStr = new SimpleDateFormat("yyyyMMdd").format(new Date());
		newDb.setInfo("BUILDDATE", dateStr);
		newDb.setInfo("DATASOURCENAME", SDFsec2pri.sourceName);
		
		newDb.setInfo("DATASOURCEVERSION", DbVersion);
		newDb.setInfo("BRIDGEDBVERSION", BridgeDbVersion);
		newDb.setInfo("DATATYPE", "Identifiers");	
		}
	
	
	private static void setupDatasources() {
		DataSourceTxt.init();
		dsId = DataSource.getExistingBySystemCode(SDFsec2pri.sourceIdCode);
		dsSymbol = DataSource.getExistingBySystemCode(SDFsec2pri.sourceSymbolCode);
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





	