package org.bridgedb.sec2pri;

import javax.xml.parsers.DocumentBuilderFactory;  
import javax.xml.parsers.DocumentBuilder;

import org.bridgedb.DataSource;
import org.bridgedb.IDMapperException;
import org.bridgedb.Xref;
import org.bridgedb.bio.DataSourceTxt;
import org.bridgedb.rdb.construct.DBConnector;
import org.bridgedb.rdb.construct.DataDerby;
import org.bridgedb.rdb.construct.GdbConstruct;
import org.bridgedb.rdb.construct.GdbConstructImpl3;
import org.w3c.dom.Document;  
import org.w3c.dom.NodeList;  
import org.w3c.dom.Node;  
import org.w3c.dom.Element;

import java.io.File;
import java.io.IOException;
import java.io.InputStream;
import java.sql.SQLException;
import java.text.SimpleDateFormat;
import java.util.Date;
import java.util.HashMap;
import java.util.HashSet;
import java.util.Map;
import java.util.Set;  
import java.util.zip.*;
import java.util.Enumeration;

public class XMLse2pri  {
	public static String sourceName = "hmdb";
	public static String sourceCode = "Ch";
	public static String perNode = "accession";
	public static String secNode = "secondary_accessions";
	public static String secNodeTag = "accession";
	public static String idOrName = "id";
	public static String DbVersion = "1.0.0";
	public static String BridgeDbVersion = "3.0.13";
	private static DataSource dsPriId;
	private static DataSource dsSecId;
	private static GdbConstruct newDb;
	
	public static void main(String args[]) throws IOException, IDMapperException, SQLException {
		try
		{
			XMLse2pri.sourceName = args[0];
			XMLse2pri.sourceCode = args[1];
			XMLse2pri.perNode = args[2];
			XMLse2pri.secNode = args[3];
			XMLse2pri.secNodeTag = args[4];
			XMLse2pri.idOrName = args[5];
			
			setupDatasources();
			File outputDir = new File("output");
			outputDir.mkdir();
			File outputFile = new File(outputDir, sourceName + "_" + XMLse2pri.idOrName + ".bridge");
			try {
				createDb(outputFile);
				} catch (IDMapperException e1) {
					// TODO Auto-generated catch block
					e1.printStackTrace();
					}
			///File inputDir = new File("input");
			//creating a constructor of file class and parsing an XML file
			//File file = new File(new FileReader(inputDir + "/" + sourceName + ".zip"));
			File file = new File("input/hmdb_metabolites_split.zip");
			try (ZipFile zipfile = new ZipFile(file)) {
				// get the Zip Entries using the entries() function
				Enumeration<? extends ZipEntry> entries
				= zipfile.entries();
				
				Map<Xref, Set<Xref>> map = new HashMap<Xref, Set<Xref>>();
				int counter = 0;
				int counter2 = 0;
				boolean finished = false;
				
				while (entries.hasMoreElements() && !finished) {
					// get the zip entry
					ZipEntry entry = entries.nextElement();
					if (!entry.isDirectory() && entry.getName() != "hmdb_metabolites.xml") {
						//an instance of factory that gives a document builder
						InputStream inputStream = zipfile.getInputStream(entry);
						DocumentBuilderFactory docBuilderFactory = DocumentBuilderFactory.newInstance();
						DocumentBuilder docBuilder = docBuilderFactory.newDocumentBuilder();
						Document document = docBuilder.parse(inputStream);
						document.getDocumentElement().normalize();
						NodeList secIdList = document.getElementsByTagName(XMLse2pri.secNode);
						NodeList priList = document.getElementsByTagName(XMLse2pri.perNode);
						Element priId = (Element) priList.item(0); // assumption: there is only one primary id used by the database
						
						if (priId != null && secIdList.getLength() != 0) {
							for (int itr = 0; itr < secIdList.getLength(); itr++) {
								Node node = secIdList.item(itr);
								if (node.getNodeType() == Node.ELEMENT_NODE) {
									Element eElement = (Element) node;
									NodeList secIds = eElement.getElementsByTagName(XMLse2pri.secNodeTag);
									for (int itr2 = 0; itr2 < secIds.getLength(); itr2++) {
										Element identifier = (Element) secIds.item(itr2);
										
										Xref secId = new Xref(identifier.getTextContent(), dsSecId, false); //the first column is the secondary id so idPrimary = false
										map.put(secId, new HashSet<Xref>());
										Xref priIdRef = new Xref(priId.getTextContent(), dsPriId);
										map.get(secId).add(priIdRef);
										}
									}
								}
							}
						counter++;
						if (counter == 5000) {
							counter2++;
							System.out.println("5k mark " + counter2 + ": " + entry);
							counter = 0;
							addEntries(map);
							map.clear();
							// finished = true;
							}
						}
					}
				addEntries(map);
				}
		newDb.finalize();
		System.out.println("[INFO]: Database finished.");
		}
		catch (Exception e) {
			e.printStackTrace();
			}
		}
	
	private static void setupDatasources() {
		DataSourceTxt.init();
		dsPriId = DataSource.getExistingBySystemCode(XMLse2pri.sourceCode);
		dsSecId = DataSource.getExistingBySystemCode(XMLse2pri.sourceCode);
	}
	
	private static void createDb(File outputFile) throws IDMapperException {
		
		newDb = new GdbConstructImpl3(outputFile.getAbsolutePath(),new DataDerby(), DBConnector.PROP_RECREATE);
		newDb.createGdbTables();
		newDb.preInsert();
		
			
		String dateStr = new SimpleDateFormat("yyyyMMdd").format(new Date());
		newDb.setInfo("BUILDDATE", dateStr);
		newDb.setInfo("DATASOURCENAME", TXTsec2pri.sourceName);
		
		newDb.setInfo("DATASOURCEVERSION", DbVersion);
		newDb.setInfo("BRIDGEDBVERSION", BridgeDbVersion);
		newDb.setInfo("DATATYPE", "Identifiers");	

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
