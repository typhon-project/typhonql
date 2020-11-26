/********************************************************************************
* Copyright (c) 2018-2020 CWI & Swat.engineering 
*
* This program and the accompanying materials are made available under the
* terms of the Eclipse Public License 2.0 which is available at
* http://www.eclipse.org/legal/epl-2.0.
*
* This Source Code may also be made available under the following Secondary
* Licenses when the conditions for such availability set forth in the Eclipse
* Public License, v. 2.0 are satisfied: GNU General Public License, version 2
* with the GNU Classpath Exception which is
* available at https://www.gnu.org/software/classpath/license.html.
*
* SPDX-License-Identifier: EPL-2.0 OR GPL-2.0 WITH Classpath-exception-2.0
********************************************************************************/

package engineering.swat.nlaemock;

import java.io.IOException;
import java.util.concurrent.TimeUnit;

import javax.servlet.ServletException;
import javax.servlet.ServletOutputStream;
import javax.servlet.http.HttpServlet;
import javax.servlet.http.HttpServletRequest;
import javax.servlet.http.HttpServletResponse;

import org.eclipse.jetty.server.HttpConfiguration;
import org.eclipse.jetty.server.HttpConnectionFactory;
import org.eclipse.jetty.server.Server;
import org.eclipse.jetty.server.ServerConnector;
import org.eclipse.jetty.servlet.ServletContextHandler;
import org.eclipse.jetty.servlet.ServletHolder;

import nl.cwi.swat.typhonql.client.DatabaseInfo;

public class NLAEMockServer {
	private static boolean resultFlag = false;

//	{
//		  "header": [
//		    "f.@id",
//		    "f.mission.SentimentAnalysis.Sentiment",
//		    "f.mission.NamedEntityRecognition.NamedEntity"
//		  ],
//		  "records": [
//		    [
//			  "48e67372-9ce7-3e92-9a03-5dc09ecbcf2e",
//		      "3",
//		      "[\"ORGANIZATION\", \"DURATION\", \"PERSON\"]"
//		    ],
//		    [
//			  "f85243a4-fe4c-33bd-bd77-e9effec2559c",
//		      "2",
//		      "[\"DURATION\", \"PERSON\"]"
//		    ]
//		  ]
//		}

	private static final String RESULT_EXAMPLE_1 ="{\n" + 
			"  \"header\": [\n" + 
			"    \"f.@id\",\n" + 
			"    \"f.mission.SentimentAnalysis.Sentiment\",\n" + 
			"    \"f.mission.NamedEntityRecognition.NamedEntity\"\n" + 
			"  ],\n" + 
			"  \"records\": [\n" + 
			"    [\n" + 
			"	  \"48e67372-9ce7-3e92-9a03-5dc09ecbcf2e\",\n" + 
			"      \"3\",\n" + 
			"      \"[\\\"ORGANIZATION\\\", \\\"DURATION\\\", \\\"PERSON\\\"]\"\n" + 
			"    ]\n" +
			"  ]\n" + 
			"}";
	
	private static final String RESULT_EXAMPLE_2 ="{\n" + 
			"  \"header\": [\n" + 
			"    \"f.@id\",\n" + 
			"    \"f.mission.SentimentAnalysis.Sentiment\",\n" + 
			"    \"f.mission.NamedEntityRecognition.NamedEntity\"\n" + 
			"  ],\n" + 
			"  \"records\": [\n" + 
			"    [\n" + 
			"	  \"f85243a4-fe4c-33bd-bd77-e9effec2559c\",\n" + 
			"      \"2\",\n" + 
			"      \"[\\\"DURATION\\\", \\\"PERSON\\\"]\"\n" + 
			"    ]\n" + 
			"  ]\n" + 
			"}";
	
	public static void main(String[] args) throws Exception {
		if (DatabaseInfo.class.getConstructors()[0].getParameters()[0].getName().equals("arg0")) {
			throw new RuntimeException(
					"TyphonQL class was not compiled with parameters flag, server cannot work without it");
		}

		if (args.length != 1) {
			System.err.println("Missing port to run the reset server on, pass it as the first argument");
			return;
		}
		
		Server server = new Server();

		HttpConfiguration config = new HttpConfiguration();
		config.setRequestHeaderSize(10*1024*1024);
		ServerConnector http = new ServerConnector(server, new HttpConnectionFactory(config));
		http.setHost("0.0.0.0");
		http.setPort(Integer.parseInt(args[0]));
		http.setIdleTimeout(30000);
		server.addConnector(http);

		ServletContextHandler context = new ServletContextHandler();

		context.setContextPath("/");

		context.setMaxFormContentSize(100 * 1024 * 1024); // 100MB should be max for parameters
		context.addServlet(jsonPostHandler(NLAEMockServer::handleQuery), "/queryTextAnalytics");
		context.addServlet(jsonPostHandler(NLAEMockServer::handleProcess), "/processText");
	
		server.setHandler(context);

		server.start();
		System.err.println("Server is running, press Ctrl-C to terminate");
		server.join();
	}
	
	private static String handleQuery(HttpServletRequest r)
			throws ServletException, IOException {
		resultFlag = !resultFlag;
		if (resultFlag)
			return RESULT_EXAMPLE_1;
		else 
			return RESULT_EXAMPLE_2;
	}
	
	private static String handleProcess(HttpServletRequest r)
			throws ServletException, IOException {
		return "{ \"ok\": \"ok\"  }"; 
	}


	
	@FunctionalInterface
	private interface ServletHandler {
		String handle(HttpServletRequest r)
				throws ServletException, IOException;
	}

	private static void handle(HttpServletRequest req, HttpServletResponse resp,
			ServletHandler handler) throws ServletException, IOException {
		try (ServletOutputStream responseStream = resp.getOutputStream()) {
			try { // nested try so that we can report an error before the stream is closed
				long start = System.nanoTime();
				String result = handler.handle(req);
				long stop = System.nanoTime();
				resp.setStatus(HttpServletResponse.SC_OK);
				resp.setHeader("QL-Wall-Time-Ms", Long.toString(TimeUnit.NANOSECONDS.toMillis(stop - start)));
				resp.setContentType("application/json");
				responseStream.print(result);
			} catch (Exception e) {
				
			}
		}
	}

	private static ServletHolder jsonPostHandler(final ServletHandler handler) {
		return new ServletHolder(new HttpServlet() {
			private static final long serialVersionUID = 4128294886643135039L;

			@Override
			protected void doPost(HttpServletRequest req, HttpServletResponse resp)
					throws ServletException, IOException {
				handle(req, resp, handler);
			}
		});
	}

}
