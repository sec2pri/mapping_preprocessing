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
import java.util.Map;
import java.util.regex.Matcher;
import java.util.regex.Pattern;
import org.bridgedb.IDMapperException;

public class chebi_sdf {
    public static String sourceName = "ChEBI";
    public static String sourceIdCode = "Ce";
    public static String DbVersion = "1";
    private static final Pattern PROPERTY = Pattern.compile("^>\\s*<([^>]+)>\\s*$");

    public static void main(String[] args) throws Exception {
        if (args.length < 2 || args.length > 3) {
            throw new IllegalArgumentException("Usage: chebi_sdf <input.sdf> <outputDir> [dbVersion]");
        }
        File inputFile = new File(args[0]);
        if (!inputFile.isFile()) throw new IOException("Input file not found: " + inputFile);
        if (args.length == 3 && !args[2].trim().isEmpty()) DbVersion = args[2].trim();

        try (BufferedReader reader = new BufferedReader(new FileReader(inputFile));
             MappingOutput output = new MappingOutput(new File(args[1]), sourceName, sourceIdCode, DbVersion)) {
            parse(reader, output);
        }
        System.out.println("[INFO]: ChEBI TSVs and BridgeDb completed.");
    }

    static void parse(BufferedReader reader, MappingOutput output) throws IOException, IDMapperException {
        Map<String, List<String>> properties = new LinkedHashMap<>();
        String property = null;
        List<String> values = new ArrayList<>();
        String line;

        while ((line = reader.readLine()) != null) {
            if ("$$$$".equals(line.trim())) {
                store(properties, property, values);
                writeRecord(properties, output);
                properties.clear();
                property = null;
                values = new ArrayList<>();
                continue;
            }

            Matcher matcher = PROPERTY.matcher(line);
            if (matcher.matches()) {
                store(properties, property, values);
                property = matcher.group(1).trim();
                values = new ArrayList<>();
            } else if (property != null) {
                if (line.isEmpty()) {
                    store(properties, property, values);
                    property = null;
                    values = new ArrayList<>();
                } else {
                    values.add(line);
                }
            }
        }

        store(properties, property, values);
        if (!properties.isEmpty()) writeRecord(properties, output);
    }

    private static void store(Map<String, List<String>> properties, String property, List<String> values) {
        if (property == null) return;
        List<String> target = properties.computeIfAbsent(property, key -> new ArrayList<>());
        for (String value : values) {
            if (value != null && !value.trim().isEmpty()) target.add(value.trim());
        }
    }

    private static void writeRecord(Map<String, List<String>> properties, MappingOutput output)
            throws IOException, IDMapperException {
        String primaryId = first(properties.get("ChEBI ID"));
        if (primaryId.isEmpty()) return;

        MappingRecord record = new MappingRecord(primaryId);
        record.setName(first(properties.get("ChEBI Name")));
        for (String id : properties.getOrDefault("Secondary ChEBI ID", new ArrayList<>())) record.addSecondaryId(id);
        for (String synonym : properties.getOrDefault("Synonyms", new ArrayList<>())) record.addSynonym(synonym);
        output.write(record);
    }

    private static String first(List<String> values) {
        return values == null || values.isEmpty() ? "" : values.get(0).trim();
    }
}
