/* Copyright (C)  2023  Tooba Abbassi-Daloii
 *                2025  Egon Willighagen <egonw@users.sf.net>
 *
 * License: Apache License 2.0
 */
package org.sec2pri;

import java.io.BufferedReader;
import java.io.File;
import java.io.FileReader;
import java.io.IOException;
import java.util.ArrayList;
import java.util.LinkedHashMap;
import java.util.List;
import java.util.Locale;
import java.util.Map;
import java.util.regex.Matcher;
import java.util.regex.Pattern;

import org.bridgedb.IDMapperException;

/**
 * Processes a ChEBI SDF file and creates the harmonized TSV and BridgeDb
 * outputs through {@link MappingOutput}.
 */
public class chebi_sdf {

    public static String sourceName = "ChEBI";
    public static String sourceIdCode = "Ce";
    public static String DbVersion = "1";

    private static final Pattern PROPERTY_HEADER =
            Pattern.compile("^>\\s*<([^>]+)>\\s*$");

    private static final String PROPERTY_PRIMARY_ID = "CHEBI ID";
    private static final String PROPERTY_NAME = "CHEBI NAME";
    private static final String PROPERTY_SECONDARY_ID = "SECONDARY CHEBI ID";
    private static final String PROPERTY_SECONDARY_ID_SHORT = "SECONDARY ID";
    private static final String PROPERTY_SYNONYM = "SYNONYM";
    private static final String PROPERTY_SYNONYMS = "SYNONYMS";

    private chebi_sdf() {
        // Utility class.
    }

    public static void main(String[] args) throws Exception {
        if (args.length < 2 || args.length > 3) {
            throw new IllegalArgumentException(
                    "Usage: chebi_sdf <input.sdf> <outputDir> [dbVersion]"
            );
        }

        File inputFile = new File(args[0]);
        if (!inputFile.isFile()) {
            throw new IOException(
                    "Input file not found: " + inputFile.getAbsolutePath()
            );
        }

        File outputDirectory = new File(args[1]);

        if (args.length == 3
                && args[2] != null
                && !args[2].trim().isEmpty()) {
            DbVersion = args[2].trim();
        }

        try (
            BufferedReader reader = new BufferedReader(
                    new FileReader(inputFile)
            );
            MappingOutput output = new MappingOutput(
                    outputDirectory,
                    sourceName,
                    sourceIdCode,
                    DbVersion
            )
        ) {
            ProcessingStatistics statistics = parse(reader, output);

            System.out.println("[INFO]: ChEBI records read: "
                    + statistics.recordsRead);
            System.out.println("[INFO]: ChEBI records written: "
                    + statistics.recordsWritten);
            System.out.println("[INFO]: Records with names: "
                    + statistics.recordsWithNames);
            System.out.println("[INFO]: Records with secondary IDs: "
                    + statistics.recordsWithSecondaryIds);
            System.out.println("[INFO]: Secondary IDs found: "
                    + statistics.secondaryIdsFound);
            System.out.println("[INFO]: Synonyms found: "
                    + statistics.synonymsFound);
        }

        System.out.println("[INFO]: ChEBI TSVs and BridgeDb completed.");
    }

    static ProcessingStatistics parse(
            BufferedReader reader,
            MappingOutput output
    ) throws IOException, IDMapperException {

        ProcessingStatistics statistics = new ProcessingStatistics();
        Map<String, List<String>> properties = new LinkedHashMap<>();

        String currentProperty = null;
        List<String> currentValues = new ArrayList<>();
        String line;

        while ((line = reader.readLine()) != null) {
            if ("$$$$".equals(line.trim())) {
                storeProperty(properties, currentProperty, currentValues);
                statistics.recordsRead++;
                writeRecord(properties, output, statistics);

                properties.clear();
                currentProperty = null;
                currentValues = new ArrayList<>();
                continue;
            }

            Matcher matcher = PROPERTY_HEADER.matcher(line);

            if (matcher.matches()) {
                storeProperty(properties, currentProperty, currentValues);
                currentProperty = normalizePropertyName(matcher.group(1));
                currentValues = new ArrayList<>();
                continue;
            }

            if (currentProperty == null) {
                // Ignore the molecular structure block before SDF properties.
                continue;
            }

            if (line.trim().isEmpty()) {
                storeProperty(properties, currentProperty, currentValues);
                currentProperty = null;
                currentValues = new ArrayList<>();
            } else {
                currentValues.add(line.trim());
            }
        }

        // Support a final record when the file lacks a trailing $$$$ marker.
        storeProperty(properties, currentProperty, currentValues);

        if (!properties.isEmpty()) {
            statistics.recordsRead++;
            writeRecord(properties, output, statistics);
        }

        return statistics;
    }

    private static void storeProperty(
            Map<String, List<String>> properties,
            String property,
            List<String> values
    ) {
        if (property == null) {
            return;
        }

        List<String> target = properties.computeIfAbsent(
                property,
                key -> new ArrayList<>()
        );

        for (String value : values) {
            if (value == null) {
                continue;
            }

            String cleaned = value.trim();
            if (!cleaned.isEmpty()) {
                target.add(cleaned);
            }
        }
    }

    private static void writeRecord(
            Map<String, List<String>> properties,
            MappingOutput output,
            ProcessingStatistics statistics
    ) throws IOException, IDMapperException {

        String primaryId = first(
                getValues(properties, PROPERTY_PRIMARY_ID)
        );

        if (primaryId.isEmpty()) {
            System.err.println(
                    "[WARN]: Skipping record "
                    + statistics.recordsRead
                    + " because it has no ChEBI ID."
            );
            return;
        }

        MappingRecord record = new MappingRecord(primaryId);

        String name = first(
                getValues(properties, PROPERTY_NAME)
        );
        record.setName(name);

        if (!name.isEmpty()) {
            statistics.recordsWithNames++;
        }

        List<String> secondaryIds = getValues(
                properties,
                PROPERTY_SECONDARY_ID,
                PROPERTY_SECONDARY_ID_SHORT
        );

        for (String secondaryId : secondaryIds) {
            record.addSecondaryId(secondaryId);
            statistics.secondaryIdsFound++;
        }

        if (!secondaryIds.isEmpty()) {
            statistics.recordsWithSecondaryIds++;
        }

        List<String> synonyms = getValues(
                properties,
                PROPERTY_SYNONYM,
                PROPERTY_SYNONYMS
        );

        for (String synonym : synonyms) {
            record.addSynonym(synonym);
            statistics.synonymsFound++;
        }

        output.write(record);
        statistics.recordsWritten++;
    }

    private static List<String> getValues(
            Map<String, List<String>> properties,
            String... propertyNames
    ) {
        List<String> result = new ArrayList<>();

        for (String propertyName : propertyNames) {
            List<String> values = properties.get(
                    normalizePropertyName(propertyName)
            );

            if (values != null) {
                result.addAll(values);
            }
        }

        return result;
    }

    private static String first(List<String> values) {
        if (values == null || values.isEmpty()) {
            return "";
        }

        for (String value : values) {
            if (value != null && !value.trim().isEmpty()) {
                return value.trim();
            }
        }

        return "";
    }

    private static String normalizePropertyName(String value) {
        if (value == null) {
            return "";
        }

        return value
                .trim()
                .replaceAll("\\s+", " ")
                .toUpperCase(Locale.ROOT);
    }

    static final class ProcessingStatistics {
        private long recordsRead;
        private long recordsWritten;
        private long recordsWithNames;
        private long recordsWithSecondaryIds;
        private long secondaryIdsFound;
        private long synonymsFound;
    }
}
