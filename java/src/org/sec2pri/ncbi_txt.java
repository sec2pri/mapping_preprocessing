package org.sec2pri;

import org.bridgedb.*;
import org.bridgedb.bio.*;
import org.bridgedb.rdb.construct.*;
import java.io.*;
import java.sql.SQLException;
import java.text.SimpleDateFormat;
import java.util.*;
import java.util.zip.GZIPInputStream;

/**
 * Mapping the secondary identifiers (retired or withdrawn identifies) to primary identifiers (currently used identifiers).
 * 
 * @author tabbassidaloii
 */

public class ncbi_txt {
    public static String sourceName = "NCBI";
    public static String sourceIdCode = "L"; // GenBank/RefSeq
    public static String sourceSynonymCode = "O"; // Gene names as synonyms
    public static String DbVersion = "1";
    public static String BridgeDbVersion = "3.0.28";
    private static DataSource dsId;
    private static DataSource dsName;
    private static GdbConstruct newDb;

    public static void main(String[] args) throws IOException, IDMapperException, SQLException {
        try {
    		//Assign the input argument to the corresponding variables
        	String sourceVersion = args[0];
        	File geneHistoryFile = new File(args[1]);
            File geneInfoFile = new File(args[2]);
            File outputDir = new File(args[3]);
            setupDatasources();
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
    		////symbol 2 alias & previous names
    		List<List<String>> listOfsymbol2alias = new ArrayList<>(); //list of the name to synonym 
            
            Map<Xref, Set<Xref>> map = new HashMap<>();
            
            //Read the file that includes the withdrawn ids
            BufferedReader accReader = new BufferedReader(
            	    new InputStreamReader(new GZIPInputStream(new FileInputStream(geneHistoryFile)))
            	);
            String line = accReader.readLine(); // read header
            Map<String, Integer> colIdx = new HashMap<>();
            String[] headers = line.split("\t");

            // Store column indexes
            for (int i = 0; i < headers.length; i++) {
                colIdx.put(headers[i], i);
            }

            while ((line = accReader.readLine()) != null) {
                if (line.trim().isEmpty()) continue;

                String[] fields = line.split("\t", -1);

                String taxId = fields[colIdx.get("#tax_id")];
                if (!taxId.equals("9606")) continue; // human genes only

                String primaryID = fields[colIdx.get("GeneID")];
                String secondaryID = fields[colIdx.get("Discontinued_GeneID")];
                String secondarySymbol = fields[colIdx.get("Discontinued_Symbol")];
                String comment = fields[colIdx.get("Discontinue_Date")];

                // Handle missing primaryID
                if (primaryID.equals("-")) {
                    primaryID = "Entry Withdrawn";
                }

                // Format comment
                if (!comment.equals("-")) {
                    comment = "Withdrawn date: " + comment + ". ";
                } else {
                    comment = "";
                }

                List<String> row = Arrays.asList(primaryID, secondaryID, secondarySymbol, comment);
                listOfsec2pri.add(row);
            }
            accReader.close();
                        
            
			//Since the data for NCBI is coming form two files, it would be more accurate to add the required information for SSSOM format while prepossessing the files
			//Add the proper predicate: 
			////IAO:0100001 for IDs merged or 1:1 replacement to one and 
			////oboInOwl:consider for IDs split or deprecated/withdrawn
            Map<String, Integer> primaryCount = new HashMap<>();
            Map<String, Integer> secondaryCount = new HashMap<>();

            for (List<String> row : listOfsec2pri) {
                String primaryID = row.get(0);
                String secondaryID = row.get(1);

                primaryCount.put(primaryID, primaryCount.getOrDefault(primaryID, 0) + 1);
                secondaryCount.put(secondaryID, secondaryCount.getOrDefault(secondaryID, 0) + 1);
            }

            List<List<String>> finalMappedList = new ArrayList<>();

            Set<String> allSecondaryIDs = new HashSet<>();
            for (List<String> row : listOfsec2pri) {
                allSecondaryIDs.add(row.get(1)); // secondaryID
            }
            
            for (List<String> row : listOfsec2pri) {
                String primaryID = row.get(0);
                String secondaryID = row.get(1);
                String secondarySymbol = row.get(2);
                String comment = row.get(3);

                Integer priCount = primaryCount.get(primaryID);
                Integer secCount = secondaryCount.get(secondaryID);

                String cardinality;
                if (primaryID.equals("Entry Withdrawn")) {
                    cardinality = "1:0";
                    priCount = null;
                } else if (priCount > 1 && secCount == 1) {
                    cardinality = "n:1";
                } else if (priCount == 1 && secCount == 1) {
                    cardinality = "1:1";
                } else if (priCount == 1 && secCount > 1) {
                    cardinality = "1:n";
                } else if (priCount > 1 && secCount > 1) {
                    cardinality = "n:n";
                } else {
                    cardinality = null;
                }

                // Predicate
                String predicateID;
                if (Arrays.asList("1:0", "1:n", "n:n").contains(cardinality)) {
                    predicateID = "oboInOwl:consider";
                } else if (Arrays.asList("1:1", "n:1").contains(cardinality)) {
                    predicateID = "IAO:0100001";
                } else {
                    predicateID = null;
                }

                // Enhanced comment
             // Enhanced comment
                if (cardinality != null) {
                    switch (cardinality) {
                        case "1:n":
                            comment += "ID (subject) is split into multiple.";
                            break;
                        case "1:1":
                            comment += "ID (subject) is replaced.";
                            break;
                        case "n:n":
                            comment += "This ID (subject) and other ID(s) are merged/split into multiple ID(s).";
                            break;
                        case "n:1":
                            comment += "This ID (subject) and other ID(s) are merged into one ID.";
                            break;
                        case "1:0":
                            comment += "ID (subject) withdrawn/deprecated.";
                            break;
                    }
                }

                // Additional note if primaryID is itself withdrawn
                if (allSecondaryIDs.contains(primaryID)) {
                    comment += " Object is also withdrawn.";
                }

                // Append release info
                comment += " Release: " + sourceVersion + ".";

                String source = "https://ftp.ncbi.nih.gov/gene/DATA/gene_history.gz";

                List<String> newRow = Arrays.asList(primaryID, secondaryID, secondarySymbol,
                                                    predicateID, cardinality, comment, source);
                finalMappedList.add(newRow);
            }
            
            for (List<String> row : finalMappedList) {
                String primaryID = row.get(0);
                String secondaryID = row.get(1);
                String secondarySymbol = row.get(2);

                if ("Entry Withdrawn".equals(primaryID)) continue;

                Xref priX = new Xref(primaryID, dsId);
                Xref secX = new Xref(secondaryID, dsId, false);
                Xref secNameX = new Xref(secondarySymbol, dsName, false);

                map.putIfAbsent(priX, new HashSet<>());
                map.get(priX).add(secX);
                if (secondarySymbol != null && !secondarySymbol.equals("-") && !secondarySymbol.isEmpty()) {
                    map.get(priX).add(secNameX);
                }
            }


            BufferedReader infoReader = new BufferedReader(
            	    new InputStreamReader(new GZIPInputStream(new FileInputStream(geneInfoFile)))
            		);
        	String infoHeader = infoReader.readLine();
        	String[] infoCols = infoHeader.split("\t");
        	Map<String, Integer> infoIdx = new HashMap<>();
        	for (int i = 0; i < infoCols.length; i++) {
        	    infoIdx.put(infoCols[i], i);
        	}

        	Set<String> nomenclatureSymbols = new HashSet<>();

        	while ((line = infoReader.readLine()) != null) {
        	    if (line.trim().isEmpty() || line.startsWith("#")) continue;

        	    String[] fields = line.split("\t", -1);

        	    String taxId = fields[infoIdx.get("#tax_id")];
        	    if (!taxId.equals("9606")) continue; // human genes only

        	    String geneId = fields[infoIdx.get("GeneID")];
        	    String symbol = fields[infoIdx.get("Symbol")];
        	    String authoritySymbol = fields[infoIdx.get("Symbol_from_nomenclature_authority")];
        	    String synonyms = fields[infoIdx.get("Synonyms")];

        	    String primarySymbol = symbol;
        	    if (!authoritySymbol.equals("-") && !authoritySymbol.equals(symbol)) {
        	        primarySymbol = symbol + "|" + authoritySymbol;
        	        nomenclatureSymbols.add(authoritySymbol);
        	    }

        	    // Add to primary list
        	    listOfpri.add(Arrays.asList(geneId, primarySymbol));

        	    // Add to alias/synonym mapping
        	    if (!synonyms.equals("-")) {
        	        for (String syn : synonyms.split("\\|")) {
        	            if (syn.trim().isEmpty()) continue;
        	            String comment;
        	            if (nomenclatureSymbols.contains(syn)) {
        	                comment = "The secondary symbol is the nomenclature symbol";
        	            } else {
        	                comment = "Unofficial symbol for the gene";
        	            }
        	            comment += " Release: " + sourceVersion + ".";
        	            listOfsymbol2alias.add(Arrays.asList(geneId, primarySymbol, syn, null, null, comment, "https://ftp.ncbi.nih.gov/gene/DATA/gene_info.gz"));
        	        }
        	    }
        	    
        	    Xref geneX = new Xref(geneId, dsId);
        	    map.putIfAbsent(geneX, new HashSet<>());
        	    map.get(geneX).add(new Xref(symbol, dsName, false));

        	    if (!synonyms.equals("-")) {
        	        for (String syn : synonyms.split("\\|")) {
        	            if (!syn.trim().isEmpty()) {
        	                map.get(geneX).add(new Xref(syn.trim(), dsName, false));
        	            }
        	        }
        	    }

        	}
        	infoReader.close();

        	// Write NCBI_secID2priID.tsv
        	File sec2priFile = new File(outputDir, sourceName + "_secID2priID.tsv");
        	BufferedWriter sec2priWriter = new BufferedWriter(new FileWriter(sec2priFile));
        	sec2priWriter.write("primaryID\tsecondaryID\tsecondarySymbol\tpredicateID\tmapping_cardinality_sec2pri\tcomment\tsource\n");
        	for (List<String> row : finalMappedList) {
        	    sec2priWriter.write(String.join("\t", row));
        	    sec2priWriter.newLine();
        	}
        	sec2priWriter.close();

        	// Write NCBI_priIDs.tsv
        	File priFile = new File(outputDir, sourceName + "_priIDs.tsv");
        	BufferedWriter priWriter = new BufferedWriter(new FileWriter(priFile));
        	priWriter.write("primaryID\tprimarySymbol\n");
        	Set<String> seen = new HashSet<>();
        	for (List<String> row : listOfpri) {
        	    String joined = String.join("\t", row);
        	    if (seen.add(joined)) {
        	        priWriter.write(joined);
        	        priWriter.newLine();
        	    }
        	}
        	priWriter.close();

        	// Write NCBI_symbol2alia&prev.tsv
        	File aliasFile = new File(outputDir, sourceName + "_symbol2alia&prev.tsv");
        	BufferedWriter aliasWriter = new BufferedWriter(new FileWriter(aliasFile));
        	aliasWriter.write("primaryID\tprimarySymbol\tsecondarySymbol\tpredicateID\tmapping_cardinality_sec2pri\tcomment\tsource\n");
        	for (List<String> row : listOfsymbol2alias) {
        	    aliasWriter.write(String.join("\t", row));
        	    aliasWriter.newLine();
        	}
        	aliasWriter.close();


            System.out.println("[INFO]: Writing database...");
            addEntries(map);
            newDb.finalize();
            System.out.println("[INFO]:  Writing TSVs and BridgeDb completed.");
        } catch (Exception e) {
            e.printStackTrace();
        }
    }

    private static void setupDatasources() {
        DataSourceTxt.init();
        dsId = DataSource.getExistingBySystemCode(sourceIdCode);
        dsName = DataSource.getExistingBySystemCode(sourceSynonymCode);
    }

    private static void createDb(File outputFile) throws IDMapperException {
        newDb = new GdbConstructImpl4(outputFile.getAbsolutePath(), new DataDerby(), DBConnector.PROP_RECREATE);
        newDb.createGdbTables();
        newDb.preInsert();

        String dateStr = new SimpleDateFormat("yyyyMMdd").format(new Date());
        newDb.setInfo("BUILDDATE", dateStr);
        newDb.setInfo("DATASOURCENAME", sourceName);
        newDb.setInfo("DATASOURCEVERSION", DbVersion);
        newDb.setInfo("BRIDGEDBVERSION", BridgeDbVersion);
        newDb.setInfo("DATATYPE", "Identifiers");
    }

    private static void addEntries(Map<Xref, Set<Xref>> dbEntries) throws IDMapperException {
        Set<Xref> addedXrefs = new HashSet<>();
        for (Xref ref : dbEntries.keySet()) {
            if (addedXrefs.add(ref)) newDb.addGene(ref);
            newDb.addLink(ref, ref);

            for (Xref target : dbEntries.get(ref)) {
                if (addedXrefs.add(target)) newDb.addGene(target);
                newDb.addLink(ref, target);
            }
            newDb.commit();
        }
    }
}
