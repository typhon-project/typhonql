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

package lang.typhonql.util;

import java.nio.ByteBuffer;
import java.nio.ByteOrder;
import java.nio.charset.StandardCharsets;
import java.util.Base64;
import java.util.UUID;

import io.usethesource.vallang.IString;
import io.usethesource.vallang.IValueFactory;

public class MakeUUID {
	private final IValueFactory vf;
	
	
	
	public MakeUUID(IValueFactory vf) {
		this.vf = vf;
	}
	
	public IString makeUUID() {
		return vf.string(randomUUID());
	}
	
	public IString hashUUID(IString key) {
		UUID uuid = UUID.nameUUIDFromBytes(key.getValue().getBytes(StandardCharsets.UTF_8));
		return vf.string(uuid.toString());
	}	

	public static String randomUUID() {
		return UUID.randomUUID().toString();
	
	}
	
	public IString uuidToBase64(IString uuid) {
		UUID actual = UUID.fromString(uuid.getValue());
		return vf.string(uuidToBase64(actual));
	}
	
	public static String uuidToBase64(UUID actual) {
		if (actual == null) {
			return null;
		}
		return Base64.getEncoder().encodeToString(uuidToBytes(actual));
	}

	public static byte[] uuidToBytes(UUID actual) {
		if (actual == null) {
			return null;
		}
		byte[] raw = new byte[16];
		ByteBuffer.wrap(raw).order(ByteOrder.BIG_ENDIAN)
			.putLong(actual.getMostSignificantBits())
			.putLong(actual.getLeastSignificantBits());
		return raw;
	}
	
	public static UUID uuidFromBytes(byte[] raw) {
		if (raw == null) {
			return null;
		}
		ByteBuffer source = ByteBuffer.wrap(raw).order(ByteOrder.BIG_ENDIAN);
		long msb = source.getLong();
		long lsb = source.getLong();
		return new UUID(msb, lsb);
	}
	
	public IString base64Encode(IString source) {
		return vf.string(Base64.getEncoder().encodeToString(
				source.getValue().getBytes(StandardCharsets.UTF_8))
        );
	}

	
	

	
}
