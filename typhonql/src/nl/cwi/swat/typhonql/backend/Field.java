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

package nl.cwi.swat.typhonql.backend;

public class Field implements Binding {
	private String reference;
	private String label;
	private String type;
	private String attribute;
	
	public Field(String reference, String label, String type) {
		super();
		this.type = type;
		this.label = label;
		this.reference = reference;
		this.attribute = "@id";
	}
	
	public Field(String reference, String label, String type, String attribute) {
		super();
		this.type = type;
		this.label = label;
		this.reference = reference;
		this.attribute = attribute;
	}
	
	public String getLabel() {
		return label;
	}
	
	public String getType() {
		return type;
	}
	
	public String getReference() {
		return reference;
	}
	
	public String getAttribute() {
		return attribute;
	}
	
	@Override
	public int hashCode() {
		return type.hashCode() *3 + label.hashCode() * 7
				+ reference.hashCode() * 11 + attribute.hashCode() * 13;
	}
	
	@Override
	public boolean equals(Object obj) {
		if (obj != null) {
			if (obj instanceof Field) {
				Field f = (Field) obj;
				return type.equals(f.type) && label.equals(f.label)
						&& reference.equals(f.reference) && attribute.equals(f.attribute);
			}
			else
				return false;
		}
		return false;
	}
	
	@Override
	public String toString() {
		return "field(" +
				String.join(", ", new String[] {reference, label, type, attribute}) 
				+ ")";
	}
}
