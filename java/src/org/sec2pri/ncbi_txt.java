package org.sec2pri;

import org.bridgedb.*;
import org.bridgedb.bio.*;
import org.bridgedb.rdb.construct.*;
import java.io.*;
import java.sql.SQLException;
import java.text.SimpleDateFormat;
import java.util.*;

public class ncbi_gene {
    public static String sourceName = "NCBI";
    public static String sourceIdCode = "L"; // GenBank/RefSeq
    public static String sourceSynonymCode = "O"; // Gene names as synonyms
    public static String DbVersion = "1";
    public static String BridgeDbVersion = "3.0.10";

    private static DataSource dsId;
    private static DataSource dsName;
    private static GdbConstruct newDb;

    public static void main(String[] args) throws IOException, IDMapperException, SQLException {
        try {
            File gene2accessionFile = new File(args[0]);
            File geneInfoFile = new File(args[1]);
            File outputDir = new File(args[2]);
            outputDir.mkdir();

            setupDatasources();

            File bridgeFile = new File(outputDir, sourceName + "_secID2priID.bridge");
            createDb(bridgeFile);

            Map<Xref, Set<Xref>> map = new HashMap<>();

            BufferedReader accReader = new BufferedReader(new FileReader(gene2accessionFile));
            String line;
            while ((line = accReader.readLine()) != null) {
                if (line.startsWith("#") || line.trim().isEmpty()) continue;

                String[] fields = line.split("\t", -1);
                String geneId = fields[1];
                String rnaAcc = fields[3];
                String protAcc = fields[5];

                Xref geneX = new Xref(geneId, dsId);
                map.putIfAbsent(geneX, new HashSet<>());

                if (!rnaAcc.equals("-")) map.get(geneX).add(new Xref(rnaAcc, dsId, false));
                if (!protAcc.equals("-")) map.get(geneX).add(new Xref(protAcc, dsId, false));
            }
            accReader.close();

            BufferedReader infoReader = new BufferedReader(new FileReader(geneInfoFile));
            while ((line = infoReader.readLine()) != null) {
                if (line.startsWith("#") || line.trim().isEmpty()) continue;

                String[] fields = line.split("\t", -1);
                String geneId = fields[1];
                String geneSymbol = fields[2];
                String synonyms = fields[4];

                Xref geneX = new Xref(geneId, dsId);
                map.putIfAbsent(geneX, new HashSet<>());
                map.get(geneX).add(new Xref(geneSymbol, dsName, false));

                if (!synonyms.equals("-")) {
                    for (String syn : synonyms.split("\\|")) {
                        map.get(geneX).add(new Xref(syn, dsName, false));
                    }
                }
            }
            infoReader.close();

            System.out.println("[INFO]: Writing database...");
            addEntries(map);
            newDb.finalize();
            System.out.println("[INFO]: NCBI BridgeDb database completed.");
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
