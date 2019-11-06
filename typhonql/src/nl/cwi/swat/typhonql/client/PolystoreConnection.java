package nl.cwi.swat.typhonql.client;

import io.usethesource.vallang.IValue;

public interface PolystoreConnection {

	IValue executeQuery(String query);

}