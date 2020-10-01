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

module lang::typhonql::Aggregation

/*


assumptions:
  - expansion of sole vars has happened
  - all aggregate functions are aliased with as

from E1 e1, ..., En en
select xj.fj, ..., fi(...) as xi
where ... (only xj stuff)
group xm.fm, ...
having ... (includes xi's from fi(...)...)


split into:

from E1 e1, ..., En en
select xj.fj, ...
where ... (only xj stuff)


and

from E1 e1, ..., En en
select xj.fj, ..., fi(...) as xi
where true
group xm.fm, ...
having ... (includes xi's from fi(...)...)




*/
