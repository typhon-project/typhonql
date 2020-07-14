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

module lang::typhonml::Bootstrap

import lang::ecore::Ecore;
import lang::ecore::IO;
import lang::ecore::Ecore2ADT;


// change this to location of the TyphonML metamodel before calling bootstrap
loc TYPHONML_ECORE = |file:///Users/tvdstorm/CWI/typhonml/it.univaq.disim.typhonml.parent/bundles/it.univaq.disim.typhonml/model/typhonml.ecore|;

@doc{Run this after the ECore meta model of TyphonML changes}
void bootstrap() {
  EPackage pkg = load(#EPackage, TYPHONML_ECORE); 
  writeEcoreADTModule("lang::typhonml::TyphonML", |project://typhonql/src/lang/typhonml/TyphonML.rsc|, pkg);
}
