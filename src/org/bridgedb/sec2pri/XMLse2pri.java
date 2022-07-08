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
import org.bridgedb.rdb.construct.GdbConstructImpl4;
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
	public static String sourceIdCode = "Ch";
	public static String sourceSymbolCode = "O"; // for hmdb (in general for metabolites, there is no system code for metabollite name, for now it is considered O
	public static String priIdNode = "accession";
	public static String secIdNode = "secondary_accessions";
	public static String secIdNodeTag = "accession"; // if the node doesn't have any tag; args[5] = NA 
	public static String priSymbolNode = "name";
	public static String secSymbolNode = "synonyms";
	public static String secSymbolNodeTag = "synonym"; // if the node doesn't have any tag; args[8] = NA 
	//public static String idOrName = "id";
	public static String DbVersion = "1.0.0";
	public static String BridgeDbVersion = "3.0.13";
	private static DataSource dsId;
	private static DataSource dsSymbol;
	private static GdbConstruct newDb;
	
	public static void main(String args[]) throws IOException, IDMapperException, SQLException {
		try {
			XMLse2pri.sourceName = args[0];
			XMLse2pri.sourceIdCode = args[1];
			XMLse2pri.sourceSymbolCode = args[2];
			XMLse2pri.priIdNode = args[3];
			XMLse2pri.secIdNode = args[4];
			XMLse2pri.secIdNodeTag = args[5];
			XMLse2pri.priSymbolNode = args[6];
			XMLse2pri.secSymbolNode = args[7];
			XMLse2pri.secSymbolNodeTag = args[8];
			
			//XMLse2pri.idOrName = args[5];
			
			setupDatasources();
			File outputDir = new File("output");
			outputDir.mkdir();
			//File outputFile = new File(outputDir, sourceName + "_" + XMLse2pri.idOrName + ".bridge");
			File outputFile = new File(outputDir, sourceName + ".bridge");

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
						// Accession primary ID
						NodeList priIdList = document.getElementsByTagName(XMLse2pri.priIdNode);
						Element priId = (Element) priIdList.item(0); // assumption: there is only one primary id used by the database
						// Adding the secondary ids if there is any
						NodeList secIdList = document.getElementsByTagName(XMLse2pri.secIdNode);
						if (priId != null && secIdList.getLength() != 0) {
							
							Xref priIdRef = new Xref(priId.getTextContent(), dsId);
							map.put(priIdRef, new HashSet<Xref>());
							
							if (!XMLse2pri.secIdNodeTag.equalsIgnoreCase("NA")) { // when there is tag for the node
								for (int itr = 0; itr < secIdList.getLength(); itr++) {
									Node node = secIdList.item(itr);
									if (node.getNodeType() == Node.ELEMENT_NODE) {
										Element eElement = (Element) node;
										NodeList secIds = eElement.getElementsByTagName(XMLse2pri.secIdNodeTag);
										for (int itr2 = 0; itr2 < secIds.getLength(); itr2++) {
											Element secId = (Element) secIds.item(itr2);
											Xref secIdRef = new Xref(secId.getTextContent(), dsId, false); //the first column is the secondary id so idPrimary = false
											map.get(priIdRef).add(secIdRef);
											}
										}
									}
								} else { // when there is no tag for the node
									Element secId = (Element) secIdList.item(0); // assumption: there is only one name used by the database
									Xref secIdRef = new Xref(secId.getTextContent(), dsId);
									map.get(priIdRef).add(secIdRef);
									}
							// Adding the primary Symbol
							NodeList priSymbolList = document.getElementsByTagName(XMLse2pri.priSymbolNode);
							Element priSymbol = (Element) priSymbolList.item(0); // assumption: there is only one primary name used by the database
							Xref priSymbolRef = new Xref(priSymbol.getTextContent(), dsSymbol);
							map.get(priIdRef).add(priSymbolRef);

							// Adding the secondary symbols if there is any
							NodeList secSymbolList = document.getElementsByTagName(XMLse2pri.secSymbolNode);
							if (secSymbolList.getLength() != 0) {
								if (!XMLse2pri.secSymbolNodeTag.equalsIgnoreCase("NA")) { // when there is tag for the node
									for (int itr = 0; itr < secSymbolList.getLength(); itr++) {
										Node node = secSymbolList.item(itr);
										if (node != null && node.getNodeType() == Node.ELEMENT_NODE) {
											Element eElement = (Element) node;
											NodeList secSymbols = eElement.getElementsByTagName(XMLse2pri.secSymbolNodeTag);
											for (int itr2 = 0; itr2 < secSymbols.getLength(); itr2++) {
												Element secSymbol = (Element) secSymbols.item(itr2);
												Xref secSymbolRef = new Xref(secSymbol.getTextContent(), dsSymbol, false); //secondary symbols so idPrimary = false
												map.get(priIdRef).add(secSymbolRef);
												}
											}
										}
									} else { // when there is no tag for the node
										Element secSymbol = (Element) secIdList.item(0); // assumption: there is only one name used by the database
										Xref secSymbolRef = new Xref(secSymbol.getTextContent(), dsSymbol);
										map.get(priIdRef).add(secSymbolRef);
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
				System.out.println("Start to the creation of the database, might take some time");
				addEntries(map);
				}
		newDb.finalize();
		System.out.println("[INFO]: Database finished.");
		System.out.println(new Date());

		}
		catch (Exception e) {
			e.printStackTrace();
			}
		}
	
	private static void setupDatasources() {
		DataSourceTxt.init();
		dsId = DataSource.getExistingBySystemCode(XMLse2pri.sourceIdCode);
		dsSymbol = DataSource.getExistingBySystemCode(XMLse2pri.sourceSymbolCode);
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
