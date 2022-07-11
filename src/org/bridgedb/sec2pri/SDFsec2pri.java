package org.bridgedb.sec2pri;
import java.io.BufferedReader;
import java.io.File;
import java.io.FileReader;
import java.io.IOException;
import java.sql.SQLException;
import java.util.*;
import org.bridgedb.IDMapperException;
import java.io.FileWriter;



public class SDFsec2pri {
	public static void main(String[] args) throws IOException, IDMapperException, SQLException {
		
		List<List<String>> listOfsec2pri = new ArrayList<>(); //list of the secondary to primary IDs
		try (BufferedReader file = new BufferedReader(new FileReader("D:/bridgeDb/GitHubRepositories/edTAD_B2B/create-bridgedb-secondary2primary/input/ChEBI/ChEBI_complete_3star.sdf"))) {
			String dataRow = file.readLine();
			String priId = "";
			String secId = "";
	        List<String> sec2pri= new ArrayList<String>(); 
			sec2pri.add("primaryID");
			sec2pri.add(",");
			sec2pri.add("secondaryID");

			while (dataRow != null) {
				boolean priLine = dataRow.startsWith("> <ChEBI ID>");
				if (priLine) {
					dataRow = file.readLine();
					if(!sec2pri.isEmpty()) listOfsec2pri.add(sec2pri);
					sec2pri = new ArrayList<>();
					priId = dataRow;
					sec2pri.add(priId);
					sec2pri.add(",");
					}
				boolean secLine = dataRow.startsWith("> <Secondary ChEBI ID>");
				if (secLine) {
					dataRow = file.readLine();
					secId = dataRow;
					sec2pri.add(secId);
					dataRow = file.readLine();
					while (dataRow.startsWith("CHEBI:")) {
						secId = dataRow;
						//System.out.println("secId: " + secId);
						sec2pri.add("\n");
						sec2pri.add(priId);
						sec2pri.add(",");
						sec2pri.add(secId);
						dataRow = file.readLine();
						}
					}
				dataRow = file.readLine();
				}
	
			FileWriter writer = new FileWriter("D:/bridgeDb/GitHubRepositories/edTAD_B2B/create-bridgedb-secondary2primary/output/ChEBI.tsv"); 
			for (int i = 0; i < listOfsec2pri.stream().count(); i++) {
				List<String> list = listOfsec2pri.get(i);
				for (String str:list) {
					writer.write(str);
					}
				writer.write(System.lineSeparator());
			}
			writer.close();
			System.out.println("[INFO]: Secondary to primary id table is written");

	
			}
		}
	}





	