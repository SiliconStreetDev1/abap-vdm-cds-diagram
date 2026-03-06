# ABAP VDM / CDS Multi-Engine Diagram Generator 🚀

Visualize your SAP CDS Virtual Data Model (VDM) hierarchies with ease.

The **VDM Diagram Generator** is an ABAP tool designed to recursively discover and visualize CDS View relationships. Supporting **ASSOCIATIONS**, **COMPOSITIONS**, and **INHERITANCE**, this tool parses your metadata via the XCO Framework to generate syntax for your preferred rendering engine. Currently it exports a String Table that you will need to export to a file.

### 🚀 What's New
The generator has been completely re-architected to support a **multi-engine rendering model**. 
* **Three Output Formats:** Natively supports **PlantUML**, **Mermaid.js**, and **D2 Lang**.
* **Universal Configuration:** A single rendering configuration object controls layout, routing, and themes across all engines natively.
Method pattern.

---

## 📋 Compatibility & Requirements

* **Primary Support:** **SAP S/4HANA 2023** and higher.
* **Legacy Support (S/4HANA 2022):** The tool may function on 2022, but it is **not fully supported**.
    * *Note:* The XCO Framework underwent significant API changes between 2022 and 2023. You may encounter "Method Not Found" exceptions or incorrect cardinality mapping on older releases.
* **XCO Framework:** Standard availability in modern S/4HANA and BTP is required.

---

## 🏗️ Architecture & Extensibility

The solution uses a strict **Template Method** design pattern. The heavy lifting (looping, scope checking, cardinality logic, and data cleansing) is locked inside the Abstract Base Engine. The concrete subclasses act purely as syntax translators.

### Core Components
1. **`ZIF_VDM_DIAGRAM_RENDERER`**: The external contract defining the universal config and the `build( )` method.
2. **`ZIF_VDM_DIAGRAM_HOOKS`**: The internal interface defining the exact rendering exits (e.g., `on_entity_start`, `on_relationship`).
3. **`ZCL_VDM_DIAGRAM_BASE`**: The abstract engine. It consumes the XCO metadata and orchestrates the calls to the interface hooks.
4. **The Renderers**: Subclasses that redefine the hooks to output specific diagram syntax.

### 🔌 How to Add a New Format
Adding a new diagram language (e.g., DOT, Structurizr) requires **zero** changes to the SAP data extraction logic. 
1. Create a new class: `CLASS zcl_vdm_diagram_custom INHERITING FROM zcl_vdm_diagram_base.`
2. Redefine the `zif_vdm_diagram_hooks` methods.
3. Use the protected `add_text( )` method to append your specific syntax inside the hooks.

---

## 🎨 Supported Renderers

| Renderer | Best For | Output Style  |
| :--- | :--- | :--- | 
| **PlantUML** | Complex, highly detailed enterprise models. | UML Class Diagrams | 
| **Mermaid.js** | Quick embedding in GitHub, Azure DevOps, or Markdown. | UML Class Diagrams | 
| **D2 Lang** | Modern, clean, declarative diagrams. | SQL Table Shapes |

---

## ☁️ Cloud (BTP/ABAP Cloud) vs. On-Premise 
The tool utilizes the Adapter Pattern to handle environment differences:
* **On-Premise:** Broader access to the ABAP Repository. Includes fallback logic to parse DDL source code via regex if the XCO API encounters unreleased or complex UNION/JOIN statements that the standard API cannot yet handle.
* **Cloud (BTP / Public Edition):** Restricted to Tier 1 (Cloud Optimized) ABAP. The generator only interacts with "Released" entities or those within your own software components. Low-level DDIC table reads (like `DDDLSVRC`) are prohibited.

---

## ⚙️ Parameter Reference

The generator is designed for inline usage. Passed to the **Generator**. Controls **what** data is extracted from SAP.

### 1. Content Selection Scope (`ty_selection`)
Controls **what** data is extracted from the SAP XCO metadata and rendered onto the canvas. 

| Parameter | Type | Description |
| :--- | :--- | :--- |
| **`cds_name`** | `String` | The root CDS view to start discovery from. Engine moves **down**, unless inheritance is true (moves **up**). |
| **`max_allowed_level`** | `Integer` | Max recursion depth. Recommended: 3-5. Default is 1. |
| **`discovery`** | `Toggle` | Logic for finding inheritance, associations, or compositions without drawing lines. |
| **`lines`** | `Toggle` | Visualization settings for drawing arrows between boxes. |
| **`base`** | `Boolean` | If true, shows the data source (tables/views) at the top. |
| **`keys`** | `Boolean` | If true, displays key fields. |
| **`fields`** | `Boolean` | If true, displays all non-key fields. |
| **`associations_fields`** | `Boolean` | Lists association names inside the entity box. |
| **`custom_developments_only`**| `Boolean` | Only draws boxes for the `Z*` and `Y*` namespaces. |
| **`include_cds`** | `Table` | Whitelist: Only these views/entities will be expanded into boxes. |
| **`exclude_cds`** | `Table` | Blacklist: These views/entities will be ignored by the generator. |

### 2. Engine-Specific Formatting (`format`)
Passed to the **Renderer** constructor. Controls **how** the diagram looks.

| Engine | Key Format Parameters |
| :--- | :--- |
| **PlantUML** | `ortho`, `modern`, `polyline`, `spaced_out` |
| **Mermaid** | `direction` (TB/LR) |
| **D2 Lang** | `direction`, `sketch_mode`, `primary_color` |

---

## 🧱 Field Rendering & Association Mapping

The generator provides granular control over the internal structure of the entity boxes. 

* **Key Fields (`keys`):** Rendered at the top of the box with a `*` or `+` prefix to denote primary identification.
* **Normal Fields (`fields`):** Standard non-key attributes listed below the keys.
* **Association Fields (`associations_fields`):** Lists the names of defined associations within the entity box itself.

### 🎯 Relationship Line Anchoring
The behavior of relationship lines (arrows) changes based on your `associations_fields` setting to ensure maximum clarity:

* **Standard Mode (`associations_fields = abap_false`):** Relationship lines are drawn from the **border of the source box** to the border of the target box. Cleanest view for high-level overviews.
* **Detailed Mode (`associations_fields = abap_true`):** When associations are listed inside the box, the generator anchors the relationship lines **directly to the specific field name** within the box. 
    * *Why use Detailed Mode?* Mapping lines directly to association fields is invaluable when a single CDS view has multiple associations to the same target view (e.g., `_CreatedByUser` and `_LastChangedByUser` both pointing to `I_User`).

---
## 🛠 Usage & Detailed Examples

### 1. Basic Generation with Granular Toggles
The engine splits relationship logic into two granular toggle sets:
* **Discovery:** Used when you want to find and display entities in the diagram **without** drawing relationship arrows (Landscape mode).
* **Lines:** When a specific line type is enabled, the engine **automatically enables** discovery for that type.

**Discovery Only (Entities without lines):**
```abap
DATA(lo_renderer) = NEW zcl_vdm_diagram_plantuml( ).

DATA(diagram_code) = NEW zcl_vdm_diagram_generator(
  renderer  = lo_renderer
  selection = VALUE #(
    cds_name          = 'I_BUSINESSPARTNER'
    max_allowed_level = 2
    discovery = VALUE #( inheritance = abap_true associations = abap_true compositions = abap_true )
  )
)->generate( ).
```
<img width="1774" height="731" alt="image" src="https://github.com/user-attachments/assets/8712e849-8080-4314-a691-a6d70c2fda03" />

**Lines Only (Auto-discovers and draws lines):**
```abap
DATA(lo_renderer) = NEW zcl_vdm_diagram_mermaid( ).

DATA(diagram_code) = NEW zcl_vdm_diagram_generator(
  renderer  = lo_renderer
  selection = VALUE #(
    cds_name          = 'I_BUSINESSPARTNER'
    max_allowed_level = 2
    lines = VALUE #( inheritance = abap_true associations = abap_true compositions = abap_true )
  )
)->generate( ).
```
<img width="4705" height="432" alt="image" src="https://github.com/user-attachments/assets/be544b0f-41a8-498e-a7de-f9b522ab7f27" />

### 2. Advanced Filtering: Inclusions & Exclusions
To prevent accidental empty diagrams, the root `cds_name` is always included by default.

**Inclusion Strategy:**
```abap
DATA(lo_renderer) = NEW zcl_vdm_diagram_plantuml( ).

DATA(diagram_code) = NEW zcl_vdm_diagram_generator(
  renderer  = lo_renderer
  selection = VALUE #(
    cds_name          = 'I_BUSINESSPARTNER'
    max_allowed_level = 2
    lines             = VALUE #( associations = abap_true )
    " INCLUSION: ONLY expand these views into boxes
    include_cds       = VALUE #( ( cds_name = 'I_BPDATACONTROLLER' )
                                 ( cds_name = 'I_BPRELATIONSHIP_2' ) )
  )
)->generate( ).
```
<img width="357" height="303" alt="image" src="https://github.com/user-attachments/assets/598bdf6d-ca15-45db-a7e8-c3c8126adeab" />

**Exclusion Strategy:**
```abap
DATA(lo_renderer) = NEW zcl_vdm_diagram_d2( ).

DATA(diagram_code) = NEW zcl_vdm_diagram_generator(
  renderer  = lo_renderer
  selection = VALUE #(
    cds_name          = 'I_BUSINESSPARTNER'
    max_allowed_level = 2
    lines             = VALUE #( associations = abap_true )
    " EXCLUDE these views from selections
    exclude_cds       = VALUE #( ( cds_name = 'I_BPDATACONTROLLER' )
                                 ( cds_name = 'I_BPRELATIONSHIP_2' ) )
  )
)->generate( ).
```
<img width="16162" height="1104" alt="image" src="https://github.com/user-attachments/assets/45164152-d92d-43f6-ae63-13410fb38108" />

### 3. Custom Development Filter (Z/Y Namespace)
Hides standard SAP noise by only rendering entity boxes for your custom developments.

```abap
DATA(lo_renderer) = NEW zcl_vdm_diagram_mermaid( ).

DATA(diagram_code) = NEW zcl_vdm_diagram_generator(
  renderer  = lo_renderer
  selection = VALUE #(
    cds_name                 = 'ZR_BloxUIHeaderTP' 
    max_allowed_level        = 6                   
    lines                    = VALUE #( compositions = abap_true associations = abap_true ) 
    custom_developments_only = abap_true " Only select entities starting with Z* or Y*
  )
)->generate( ).
```
<img width="855" height="1770" alt="image" src="https://github.com/user-attachments/assets/86bf9ce6-c0bb-4412-b428-27f031f9ade5" />

### 4. The "Kitchen Sink" / Full Layout Config (PlantUML)
Generates a highly detailed, modern PlantUML diagram showing absolutely everything.

```abap
DATA(format) = VALUE zcl_vdm_diagram_plantuml=>ty_format(
    ortho = abap_false
).

DATA(lo_renderer) = NEW zcl_vdm_diagram_plantuml( format ).

DATA(diagram_code) = NEW zcl_vdm_diagram_generator(
  renderer  = lo_renderer
  selection = VALUE #(
    cds_name                       = 'ZR_BloxUIHeaderTP'
    max_allowed_level = 3
    keys                           = abap_true
    fields                         = abap_true
    base                           = abap_true
    associations_fields            = abap_true
    lines-associations             = abap_true
    lines-compositions             = abap_true
    lines-inheritance              = abap_true
    force_render_all_relationships = abap_false
  )
)->generate( ).
```
<img width="665" height="1130" alt="image" src="https://github.com/user-attachments/assets/3dbbf43f-06d6-4f29-a3e4-b6ce34f6f9af" />

### 5. The High-Level Architecture (Mermaid.js)
Strips away noise, hiding fields and base tables. Perfect for GitHub Markdown.

```abap
DATA(lo_renderer) = NEW zcl_vdm_diagram_d2( ).

DATA(diagram_code) = NEW zcl_vdm_diagram_generator(
  renderer  = lo_renderer
  selection = VALUE #(
    cds_name                       = 'I_BPCurrentDefaultAddress'
    keys                           = abap_false
    max_allowed_level = 2
    fields                         = abap_true
    base                           = abap_true
    lines-associations             = abap_true
    lines-compositions             = abap_true
    lines-inheritance              = abap_true
  )
)->generate( ).
```
<img width="2702" height="12120" alt="image" src="https://github.com/user-attachments/assets/7dfca2d4-e209-4d49-b600-1764399d1021" />

### 6. The Pure Database Schema (D2 Lang)
Maps out a strict data schema using D2. Focuses only on keys, fields, and standard associations (foreign keys).

```abap
DATA(lo_renderer) = NEW zcl_vdm_diagram_d2( ).

DATA(diagram_code) = NEW zcl_vdm_diagram_generator(
  renderer  = lo_renderer
  selection = VALUE #(
    cds_name                       = 'I_BPCurrentDefaultAddress'
    max_allowed_level = 1
    keys                           = abap_true
    fields                         = abap_true
    base                           = abap_true
    lines-associations             = abap_true
    lines-compositions             = abap_false " Turn off Composition
    lines-inheritance              = abap_false " Turn off Inheritance
    force_render_all_relationships = abap_true  " Force all target tables to draw
  )
)->generate( ).
```
<img width="2006" height="1282" alt="image" src="https://github.com/user-attachments/assets/035be09d-b4dc-40fd-b49d-4126ab41f28a" />

---
## 🗺 Roadmap

**Fiori Application:** We are planning a full-stack SAP Fiori application to dynamically generate and display these diagrams interactively within the SAP environment.

---

## 📄 License & Terms

© 2026 Silicon Street Limited. All Rights Reserved.

**Usage Terms:**
1. **INTERNAL USE:** Permission is granted to use this code for internal business documentation purposes within a single organization at no cost.
2. **NON-REDISTRIBUTION:** You may **NOT** redistribute, sell, or include this source code (or derivatives thereof) in any commercial software, package, or library.
3. **PAID SERVICES:** Use of this code to provide paid consulting or documentation services to third parties requires a **Commercial License**.
4. **MODIFICATIONS:** Any modifications remain subject to this license.

**DISCLAIMER:** THIS SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND. IN NO EVENT SHALL THE AUTHORS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY ARISING FROM THE USE OF THE SOFTWARE.

**FOR COMMERCIAL LICENSING INQUIRIES:** admin@siliconst.co.nz
