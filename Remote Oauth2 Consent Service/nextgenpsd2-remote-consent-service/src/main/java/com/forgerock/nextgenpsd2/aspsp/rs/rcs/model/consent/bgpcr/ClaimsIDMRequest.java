/***************************************************************************
 *  Copyright 2019 ForgeRock
 *
 * Licensed under the Apache License, Version 2.0 (the "License");
 * you may not use this file except in compliance with the License.
 * You may obtain a copy of the License at
 *
 *    http://www.apache.org/licenses/LICENSE-2.0
 *
 *  Unless required by applicable law or agreed to in writing, software
 *  distributed under the License is distributed on an "AS IS" BASIS,
 *  WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
 *  See the License for the specific language governing permissions and
 *  limitations under the License.
 ***************************************************************************/
package com.forgerock.nextgenpsd2.aspsp.rs.rcs.model.consent.bgpcr;

import java.io.Serializable;
import java.util.List;

import com.fasterxml.jackson.annotation.JsonIgnoreProperties;
import com.fasterxml.jackson.annotation.JsonUnwrapped;
import com.google.gson.annotations.SerializedName;

import lombok.Builder;
import lombok.Getter;
import lombok.Setter;
import lombok.ToString;
@Setter
@Getter
@ToString
@Builder
@JsonIgnoreProperties(ignoreUnknown = true)
public class ClaimsIDMRequest implements Serializable {
	/**
	 * 
	 */
	private static final long serialVersionUID = 1190108878490019828L;
	@SerializedName("sub")
	private String sub;
	@SerializedName("recurringIndicator")
	private String recurringIndicator;
	@SerializedName("validUntil")
	private String validUntil;
	@SerializedName("frequencyPerDay")
	private String frequencyPerDay;
	@SerializedName("combinedServiceIndicator")
	private String combinedServiceIndicator;
	@JsonUnwrapped
	private List<AccountsIDMRequest> accounts;

}
