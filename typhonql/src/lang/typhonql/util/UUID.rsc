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

module lang::typhonql::util::UUID

/*

All identity management is done by TyphonQL using UUIDs.
This module define a single function to create such UUIDs.

*/

@javaClass{lang.typhonql.util.MakeUUID}
java str makeUUID();

@javaClass{lang.typhonql.util.MakeUUID}
java str hashUUID(str key);


@javaClass{lang.typhonql.util.MakeUUID}
java str uuidToBase64(str uuid);

@javaClass{lang.typhonql.util.MakeUUID}
java str base64Encode(str contents);
