package org.sec2pri;

import java.util.LinkedHashSet;
import java.util.Set;

final class MappingRecord {
    final String primaryId;
    String name = "";
    final Set<String> secondaryIds = new LinkedHashSet<>();
    final Set<String> synonyms = new LinkedHashSet<>();

    MappingRecord(String primaryId) {
        this.primaryId = clean(primaryId);
    }

    boolean hasPrimaryId() {
        return !primaryId.isEmpty();
    }

    void setName(String value) {
        name = clean(value);
    }

    void addSecondaryId(String value) {
        String cleaned = clean(value);
        if (!cleaned.isEmpty() && !cleaned.equals(primaryId)) secondaryIds.add(cleaned);
    }

    void addSynonym(String value) {
        String cleaned = clean(value);
        if (!cleaned.isEmpty() && !cleaned.equals("-") && !cleaned.equals(name)) synonyms.add(cleaned);
    }

    private static String clean(String value) {
        return value == null ? "" : value.trim();
    }
}
