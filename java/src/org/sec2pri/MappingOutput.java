package org.sec2pri;

import java.io.BufferedWriter;
import java.io.Closeable;
import java.io.File;
import java.io.IOException;
import java.nio.charset.StandardCharsets;
import java.nio.file.Files;
import java.text.SimpleDateFormat;
import java.util.Date;
import java.util.HashSet;
import java.util.Set;

import org.bridgedb.BridgeDb;
import org.bridgedb.DataSource;
import org.bridgedb.IDMapperException;
import org.bridgedb.Xref;
import org.bridgedb.bio.DataSourceTxt;
import org.bridgedb.rdb.construct.DBConnector;
import org.bridgedb.rdb.construct.DataDerby;
import org.bridgedb.rdb.construct.GdbConstruct;
import org.bridgedb.rdb.construct.GdbConstructImpl4;

final class MappingOutput implements Closeable {
    static final String WITHDRAWN = "Entry Withdrawn";

    private final BufferedWriter primaryWriter;
    private final BufferedWriter mappingWriter;
    private final BufferedWriter synonymWriter;
    private final DataSource idDataSource;
    private final GdbConstruct database;
    private final Set<Xref> addedXrefs = new HashSet<>();
    private long recordCount;

    MappingOutput(File outputDir, String sourceName, String sourceIdCode, String databaseVersion)
            throws IOException, IDMapperException, ClassNotFoundException {
        if (!outputDir.exists() && !outputDir.mkdirs()) {
            throw new IOException("Cannot create output directory: " + outputDir);
        }
        if (!outputDir.isDirectory()) {
            throw new IOException("Output path is not a directory: " + outputDir);
        }

        DataSourceTxt.init();
        idDataSource = DataSource.getExistingBySystemCode(sourceIdCode);
        if (idDataSource == null) {
            throw new IllegalArgumentException("Unknown BridgeDb datasource system code: " + sourceIdCode);
        }

        primaryWriter = Files.newBufferedWriter(
                new File(outputDir, sourceName + "_priIDs.tsv").toPath(), StandardCharsets.UTF_8);
        mappingWriter = Files.newBufferedWriter(
                new File(outputDir, sourceName + "_secID2priID.tsv").toPath(), StandardCharsets.UTF_8);
        synonymWriter = Files.newBufferedWriter(
                new File(outputDir, sourceName + "_name2synonym.tsv").toPath(), StandardCharsets.UTF_8);

        writeRow(primaryWriter, "primaryID");
        writeRow(mappingWriter, "primaryID", "secondaryID");
        writeRow(synonymWriter, "primaryID", "name", "synonym");

        Class.forName("org.apache.derby.jdbc.EmbeddedDriver");
        File bridgeFile = new File(outputDir, sourceName + "_secID2priID.bridge");
        database = new GdbConstructImpl4(
                bridgeFile.getAbsolutePath(), new DataDerby(), DBConnector.PROP_RECREATE);
        database.createGdbTables();
        database.preInsert();
        database.setInfo("BUILDDATE", new SimpleDateFormat("yyyyMMdd").format(new Date()));
        database.setInfo("DATASOURCENAME", sourceName);
        database.setInfo("DATASOURCEVERSION", databaseVersion);
        database.setInfo("BRIDGEDBVERSION", BridgeDb.getVersion());
        database.setInfo("DATATYPE", "Identifiers");
    }

    void write(MappingRecord record) throws IOException, IDMapperException {
        if (record == null || !record.hasPrimaryId()) return;
        writePrimary(record.primaryId);
        for (String secondaryId : record.secondaryIds) writeMapping(record.primaryId, secondaryId);
        writeNames(record);
        addBridgeRecord(record);
        recordCount++;
        if (recordCount % 5000 == 0) {
            database.commit();
            System.out.println("[INFO]: Processed " + recordCount + " records");
        }
    }

    void writeWithdrawn(String secondaryId) throws IOException {
        String id = sanitize(secondaryId).trim();
        if (!id.isEmpty()) writeRow(mappingWriter, WITHDRAWN, id);
    }

    private void writePrimary(String primaryId) throws IOException {
        writeRow(primaryWriter, primaryId);
    }

    private void writeMapping(String primaryId, String secondaryId) throws IOException {
        writeRow(mappingWriter, primaryId, secondaryId);
    }

    private void writeNames(MappingRecord record) throws IOException {
        if (record.name.isEmpty() && record.synonyms.isEmpty()) return;
        if (record.synonyms.isEmpty()) {
            writeRow(synonymWriter, record.primaryId, record.name, "");
            return;
        }
        for (String synonym : record.synonyms) {
            writeRow(synonymWriter, record.primaryId, record.name, synonym);
        }
    }

    private void addBridgeRecord(MappingRecord record) throws IDMapperException {
        Xref primary = new Xref(record.primaryId, idDataSource);
        addGene(primary);
        database.addLink(primary, primary);
        for (String secondaryId : record.secondaryIds) {
            Xref secondary = new Xref(secondaryId, idDataSource, false);
            addGene(secondary);
            database.addLink(primary, secondary);
        }
        if (!record.name.isEmpty()) database.addAttribute(primary, "Synonym", record.name);
        for (String synonym : record.synonyms) database.addAttribute(primary, "Synonym", synonym);
    }

    private void addGene(Xref xref) throws IDMapperException {
        if (addedXrefs.add(xref)) database.addGene(xref);
    }

    static void writeRow(BufferedWriter writer, String... values) throws IOException {
        for (int i = 0; i < values.length; i++) {
            if (i > 0) writer.write('\t');
            writer.write(sanitize(values[i]));
        }
        writer.newLine();
    }

    private static String sanitize(String value) {
        return value == null ? "" : value.replace('\t', ' ').replace('\r', ' ').replace('\n', ' ');
    }

    @Override
    public void close() throws IOException {
        IOException failure = null;
        try { primaryWriter.close(); } catch (IOException e) { failure = e; }
        try { mappingWriter.close(); } catch (IOException e) { if (failure == null) failure = e; }
        try { synonymWriter.close(); } catch (IOException e) { if (failure == null) failure = e; }
        try {
            database.commit();
            database.finalize();
        } catch (IDMapperException e) {
            if (failure == null) failure = new IOException("Could not finalize BridgeDb database", e);
        }
        if (failure != null) throw failure;
    }
}
