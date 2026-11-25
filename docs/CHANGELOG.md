# Changelog

Most recent first. Pre-1.0: free to break; deprecations documented here. SemVer-stable from v1.0.0.

> Note: v1.1.0–v1.4.1 (MeshIO / 3MF / glTF / JWW) shipped as tagged GitHub releases without entries here; this log resumes at v1.5.0.

## v2.0.0-beta.12 (2026-11-25)

**Pre-release, pinned exactly to OCCTSwift 4.0.0-beta.6.** A consumer only gets this by naming it; the stable line stays at v1.8.0.

**In this release.** SwiftDXF 0.6 is adopted (the cap moves from 0.5.x to 0.6.x, from 0.6.1), and `ShapeLoader` now says everything it leaves out of the compound it returns: `.noEdges` for the eight entity types that have no edge here (text, dimensions, hatches, leaders, tolerance frames, solid fills, wipeouts and 3D faces), `.degenerate` for geometry with no size, and `.notBuilt` for geometry OCCT would not build ([#91](https://github.com/SecondMouseAU/OCCTSwiftIO/issues/91)). **Breaking in two ways:** the three new `DrawingWarning.Kind` cases break an exhaustive `switch` over `Kind`, and `ShapeLoadResult.warnings` is no longer empty for a drawing with text or a dimension. The compound is unchanged. A consumer that cannot resolve SwiftDXF 0.6.1 or later alongside this package cannot use it.

**SwiftDXF 0.6 is adopted, and the shapes path says what it read and made no edge of ([#91](https://github.com/SecondMouseAU/OCCTSwiftIO/issues/91)).** The cap moves from 0.5.x to 0.6.x: the requirement is `.upToNextMinor(from: "0.6.1")` (0.6.1 is what this was measured against, and compares an attribute's tag with its definition's as written, which decides which constant attributes of a block are counted below), so that a later minor that adds an entity case does not break a fresh resolve again, as 0.4.0 and 0.6.0 did (#60, #91); it is adopted by raising the cap. SwiftDXF 0.6.0 adds the `DXF.Entity` cases `.tolerance`, `.solid`, `.wipeout` and `.face3D`, and reads `SOLID`, `WIPEOUT`, `3DFACE` and `TOLERANCE` as entities and a block's `ATTDEF`s onto the block (`Block.attributeDefinitions`), where 0.5 counted all of them as skipped. `DXFLoader` makes no edge of the four, as of a hatch or a leader, but it no longer drops any of them without a word.

- **A new warning, `DrawingWarning.Kind.noEdges`,** is given by the shapes path (`ShapeLoader`, `DXFLoader.load`, `DWGLoader` and `JWWLoader` when they build shapes) for each type and layer of entity it read and made no edge of: `TEXT` (which is `MTEXT` too), `DIMENSION`, `HATCH`, `LEADER`, `TOLERANCE`, `SOLID`, `WIPEOUT` and `3DFACE`. It has the type, the layer and the count, and an entity in a block that was expanded counts once for each reference. `DrawingLoader` never gives it: it returns the entities themselves, so nothing is left out there. **This is source-breaking for an exhaustive `switch` over `DrawingWarning.Kind`**, as `extrusionNotApplied` and `expansionTruncated` were in beta.6.
- **Two more, `.degenerate` and `.notBuilt`, for drawable geometry that makes no edge.** The shapes path dropped these without a word. `.degenerate` is geometry with no size: a `LINE` with equal end points in x and y (its z is not used), a `CIRCLE` or `ARC` with no positive radius, a polyline with no vertices or a segment between equal points (counted as a segment, not an entity; a closed polyline that repeats its first vertex is ordinary and not counted), and an `ELLIPSE` or `SPLINE` that SwiftDXF's fit gives no pieces for (its degenerate input, such as an ellipse of ratio 0 or a spline of one point). `.notBuilt` is geometry with a size that OCCT would not make an edge of, such as a `LINE` with an infinite coordinate, and, with no type, edges that were made and could not be joined into a compound, which loses all of them. Each has the type, the layer and the count, which is entities, or segments of a polyline, or pieces of a fit. Nothing is built differently: the same edges come out as before, and a drawing with none of this carries no new warning.
- **What a consumer of `ShapeLoader` sees.** `ShapeLoadResult.warnings` is no longer empty for a drawing that has text or a dimension: before, only the four that SwiftDXF 0.5 counted as skipped (`SOLID`, `WIPEOUT`, `3DFACE` and `TOLERANCE`) were warned about, as `.skippedEntities`, and a `TEXT`, `DIMENSION`, `HATCH` or `LEADER` never was. A caller that treats any warning as a problem should look at `kind`: `.noEdges` is information about the format's limit, not damage to the file, `.degenerate` is geometry with no size to lose, and `.notBuilt` is the one that may be a real loss. The compound is unchanged.
- **The shapes path reads attributes.** `shapeReadOptions` now sets `expandAttributes`, so the visible attributes of a block reference, and the constant attributes of its block, come through as `TEXT` and are counted. Without it SwiftDXF 0.6 keeps an `ATTRIB` on its reference and an `ATTDEF` on its block, and a drawing's drawn text would be counted short. `ShapeLoader` and `DrawingLoader` still agree on every warning but this new kind, except in one corner: a drawing whose only content is the attribute values of references to blocks with no entities is empty to `DrawingLoader` (`.emptyDrawing`) and holds text on the shapes path.
- **`DrawingLoader` and an `ATTDEF` or a `SOLID`.** They are no longer `.skippedEntities`: a `SOLID`, `WIPEOUT`, `3DFACE` and `TOLERANCE` are in `drawing.entities`, and an `ATTDEF` is on its block. A DXF with only unmodelled types (an `MLINE`, say) is still counted as skipped, by type and layer.
- **Tests.** `ShapeNoEdgeWarningTests`: each of the eight types gives one warning with its type, layer and count and no edge; counts by type and layer, in order, and once for each reference of a block; a visible constant attribute is counted as `TEXT` (and the test fails with `expandAttributes` off); a drawing of edges alone has none; `DrawingLoader` has none; a DWG's `DIMENSION` has its layer. Thirteen expectations in six tests that assumed 0.5's skipped-entity report now follow 0.6: the tests of skipped entities use an `MLINE`, a type SwiftDXF still does not model, in place of a `SOLID`, and a new `DrawingLoaderTests` test holds that a `SOLID`, `WIPEOUT`, `3DFACE` and `TOLERANCE` are entities with no warning. `ShapeDroppedWarningTests` (twelve tests): each degenerate cause, a polyline segment counted alone, a closed polyline that repeats its first vertex and a one-vertex polyline that are not counted, a line that differs only in z, an ellipse and a spline that fit to nothing, a `LINE` OCCT will not build, edges that cannot be joined into a compound, a drawing of valid geometry that carries none, `DrawingLoader` that has none, and the tally's order. The two tests that compared the shapes path's warnings with `DrawingLoader`'s now leave out the three kinds only the shapes path gives. No DWG fixture here has a skipped entity under 0.6, so the rule that a DWG's skipped entities have no layer is held by the DXF test that reads with `layersKnown: false`.

**SwiftJWW 2.0.0: each rebuilt dimension's piece roles come from SwiftJWW, and a JWW declares its length unit ([#90](https://github.com/SecondMouseAU/OCCTSwiftIO/issues/90)).** The minimum moves from SwiftJWW 1.5.0 to 2.0.0, a major release (its `RecoveredDimension.elementIndices` is now computed and `DXFWriter.Report.init` loses its `recoveredDimensionElements:` parameter; this package sets neither, so nothing here breaks). The whole package and its tests compile against it with no other change.

- **Piece roles are SwiftJWW's decision.** `RebuiltDimension.pieces` takes each piece's `kind` from `DXFWriter.Report.recoveredDimensionPieces` (SwiftJWW#35), mapped one to one from SwiftJWW's `Role`, instead of working it out again. The 0.001 sine that told a dimension line from an extension line, a copy of SwiftJWW's own threshold, is gone, so the two cannot drift apart. The mapping names every role with no default, so a role SwiftJWW adds stops this package compiling until it is placed. Nothing a consumer sees changes: on the JNR 2120 the 29 rebuilt dimensions still list 174 pieces (29 value texts, one copy, 58 arrow points, 30 dimension lines, 56 extension lines), and on the 2120 and dd12 every piece has the role `recoveringDimensions()` gave it.
- **A JWW declares millimetres, so it no longer has the `unitsNotDeclared` warning.** SwiftJWW's DXF text now has `$INSUNITS` 4 (SwiftJWW#34), so `DrawingResult.drawing.insUnits` is 4 for a JWW and neither `DrawingLoader` nor `ShapeLoader` says the file declares no length unit. This is a change a consumer can see: a caller that treated that warning on a JWW as "assume millimetres" no longer gets it, and has the unit in the drawing. SwiftDXF's contour step reads millimetres from the drawing too, so `DXFLoader.contourFaces(of:)` on a JWW's drawing no longer has the `unitlessAssumed` warning. Nothing else in the JWW path adds a unit warning.
- **The DXF text's version is not the JWW's.** SwiftJWW's header also declares `$ACADVER` `AC1009` (SwiftJWW#34), so `DrawingResult.drawing.version` is `AC1009` for a JWW (it was empty). `DrawingResult.source.version` is still the JWW's own (`700`, `351`), which the JWW path has always taken from the file and not the drawing; a test now holds both. Nothing in the JWW path reads the DXF's version.
- **Tests.** The JWW read in `DrawingLoaderTests` now expects no `unitsNotDeclared` and `insUnits` 4 where it expected the warning; new tests cover each `JWWFixture` file (thirteen, from the plain plate to a block at scale) on `DrawingLoader` (expanded or not) and on `ShapeLoader`, the JWW's `source.version` against the DXF's, and the contour step. `JWWRebuiltPiecesTests` holds the role mapping to a written table, a role that contradicts its element's geometry to be taken as given (so no role is worked out here), each piece's kind to the report's role for every element of three written drawings, and, on the 2120 and dd12 where they are on the machine, every piece to the role `recoveringDimensions()` gave it as well as the extension lines to its geometry. The 2120 and dd12 tests also check for no `unitsNotDeclared`.

## v2.0.0-beta.11 (2026-11-25)

**Pre-release, pinned exactly to OCCTSwift 4.0.0-beta.6.** A consumer only gets this by naming it; the stable line stays at v1.8.0.

**In this release.** A fix for a `DirectoryWatcher` change that could be lost while the watcher attached ([#80](https://github.com/SecondMouseAU/OCCTSwiftIO/issues/80)); the pieces of each rebuilt JWW dimension ([#77](https://github.com/SecondMouseAU/OCCTSwiftIO/issues/77)) and solid fills in blocks in the `SOLID` warning ([#81](https://github.com/SecondMouseAU/OCCTSwiftIO/issues/81)); and SwiftDXF held below 0.6.0 so a fresh resolve compiles ([#91](https://github.com/SecondMouseAU/OCCTSwiftIO/issues/91)). Three changes have no effect on a consumer ([#30](https://github.com/SecondMouseAU/OCCTSwiftIO/issues/30)): the planar vertex, line and arc edges `DXFLoader` builds now come from one internal helper, `MeshIO`'s OBJ and PLY readers share one weld initialiser, and the docs state the DWG limits, the formats table and the install line in one place each. `ecosystem.yml` now lists every package `Package.swift` depends on ([#84](https://github.com/SecondMouseAU/OCCTSwiftIO/issues/84)).

**`DirectoryWatcher` no longer misses a change made while it is attaching ([#80](https://github.com/SecondMouseAU/OCCTSwiftIO/issues/80)).** The watcher reads the watched path (opens it, snapshots a directory) and then registers the kevent that watches it, and registration is not synchronous with that read. kqueue reports only changes made after registration, so a file written into a directory in that gap was never reported, and neither was an intermediate directory created while the watcher sat on a missing ancestor: `mkdir` then an immediate write of the first file into it could be lost, about 3 times in 100 under CPU load. The watcher now reads the path again once its source is registered and reports the difference; it also re-resolves a fallback ancestor, and re-attaches to a path that was deleted or replaced in the gap. No API change and no change to what is reported in the ordinary case; a change landing in the gap is now reported where it was lost (and may rarely be reported twice, as one write can already produce more than one notification). The `DirectoryWatcher` tests that failed intermittently (`t_startsCleanlyWhenMultipleAncestorLevelsAreMissing`, `t_recoversWhenAFallbackAncestorIsDeletedAndRecreated`) were this race, not slow delivery: a failing run never fired, even given 15 s. Four new tests make a change at exactly that point through an internal `testHookBeforeArming` seam, so they do not depend on timing. `t_repeatedStartStopDoesNotLeakFileDescriptors` was a separate test-only flake (it counted the whole process's descriptors while other tests ran) and now counts only the descriptors under its own directory.

**Each rebuilt JWW dimension lists the pieces it was built from ([#77](https://github.com/SecondMouseAU/OCCTSwiftIO/issues/77)).** `DrawingResult.RebuiltDimension` named each dimension SwiftJWW rebuilt from loose pieces by the identity of its `.dimension` alone, so a consumer could not see what the recovery had paired. It now has `pieces`: for each loose element the dimension was built from, its `kind` (`valueText`, `valueTextCopy`, `arrowPoint`, `dimensionLine` or `extensionLine`), its `points` at full size (both ends of a line, otherwise one point), its `layer` as written (`0-E`) and its `elementIndex` among the JWW file's top-level elements. The elements come from SwiftJWW 1.5.0's writer report (`DXFWriter.Report.recoveredDimensionElements`, SwiftJWW#22). A line parallel to the dimension (the angle between them under a thousandth of a radian, as SwiftJWW's recovery takes it) is a dimension line, and any other an extension line. A piece two dimensions share, such as the one dimension line of a chain, is listed under each.

- **Source compatible.** `RebuiltDimension.init(identity:pieces:)` defaults `pieces` to `[]`, so a call to `init(identity:)` still compiles. A rebuilt dimension read from a JWW now carries its pieces, so it no longer equals one made from its identity alone; compare `identity` for that. One existing test made that comparison and now compares identities.
- **The copies of the writer's scale rule and layer naming are gone.** The factor each layer group was multiplied by is the writer report's `appliedScales`, and layer names come from `DXFWriter.layerName`, so the internal `appliedScale` and `layerName` are removed, with the note to check them when moving SwiftJWW. A group's `scaleNotStated` warning now follows from what the writer did: it is given when the factor applied differs from the scale the group states. Nothing a consumer sees changes. `LayerGroupScale.layerNamePrefix` still forms its prefix itself, and a test holds it to `DXFWriter.layerName` for every group and layer. One number is copied from SwiftJWW instead: the 0.001 sine that tells a dimension line from an extension line, which its recovery uses; the writer's report does not say each piece's role, and a test on the real drawings checks the labels against the recovery.
- **Solid fills in blocks are reported ([#81](https://github.com/SecondMouseAU/OCCTSwiftIO/issues/81)).** The `SOLID` warning counted only the fills at the top level, so a fill inside a block was never reported. SwiftJWW 1.5.0 counts them (SwiftJWW#24), and the warning now counts them as the `unreadable` warning counts: once for each placement of the block when blocks are expanded (the default, and the shapes path), and once in each block definition when they are not, when the message says how many are in block definitions as the `unreadable` message does. A drawing with fills only at the top level gets the same warning as before; one with fills in blocks gets a higher count, or a warning where it had none.
- **Tests.** `JWWRebuiltPiecesTests`: the dimensioned plate written in the test lists its six pieces exactly; two chained dimensions written in the test share their dimension line, an arrow point and an extension line, and a value stored twice is a `valueTextCopy`; a chain in layer group A at 1:5 is on layers `A-E` and multiplied by 5; a vertical and a slanted dimension label their dimension line and extension lines; the layer-name prefix agrees with the writer. On the JNR 2120, where it is on the machine, the 29 rebuilt dimensions list 174 pieces (29 value texts, one copy, 58 arrow points, 30 dimension lines and 56 extension lines), which together are exactly the 125 elements on layer `0-E`, and each dimension's two arrow points are its measured distance apart to within 1e-5; on the 2120 and on dd12 the lines labelled extension lines are exactly those SwiftJWW's recovery found. `JWWFullSizeTests` gains a solid fill in a block placed twice, beside one at the top level: 3 with blocks expanded, on both paths, and 2 without, one of them in a block definition. The test target now depends on SwiftJWW directly, to read the 2120's elements.

**SwiftDXF is capped below 0.6.0 for now ([#91](https://github.com/SecondMouseAU/OCCTSwiftIO/issues/91)).** The requirement was `from: "0.5.0"`, which SwiftPM resolves to the newest 0.x, and SwiftDXF 0.6.0 (and 0.6.1) did not compile with `DXFLoader`: it adds the `DXF.Entity` cases `.tolerance`, `.solid`, `.wipeout` and `.face3D`, and it reads `SOLID`, `WIPEOUT`, `3DFACE`, `TOLERANCE` and a block's `ATTDEF`s instead of counting them as skipped, which six tests and the skipped-entity warnings assume. The requirement is now `.upToNextMinor(from: "0.5.0")` (0.5.x). Nothing in the package changes; adopting 0.6.x is tracked in #91.

## v2.0.0-beta.10 (2026-11-19)

**Pre-release, pinned exactly to OCCTSwift 4.0.0-beta.6.** A consumer only gets this by naming it; the stable line stays at v1.8.0.

**Newer readers underneath.** The minimum versions move to SwiftJWW 1.5.0, SwiftDXF 0.5.0 and SwiftDWG 0.2.0, and the full suite passes on them.

- **SwiftJWW 1.5.0.** An elliptical arc with a negative sweep is written as the part of the ellipse it covers, not the rest of it, so the known limit noted under #67 below is gone (SwiftJWW#23); an ellipse with a minor-to-major ratio above 1 is written as valid DXF (SwiftJWW#27). It also counts solid fills inside blocks (`Drawing.skippedSolidCount`, SwiftJWW#24) and its writer report names the pieces each rebuilt dimension was built from (SwiftJWW#22); this package does not use either yet: the `SOLID` warning still gives the top-level count, and recording the pieces is [#77](https://github.com/SecondMouseAU/OCCTSwiftIO/issues/77).
- **SwiftDXF 0.5.0.** The `string` of a `.text` entity is the text as it reads: `%%c`, `%%d` and `%%p` become `⌀`, `°` and `±`, MTEXT formatting codes are removed, and stacked tolerances are kept as data in `Drawing.textContent(ofEntityAt:)` (SwiftDXF#32). This package never reads the string, so nothing here changes, but a caller of `DrawingLoader` gets decoded text for a DXF, a DWG and a JWW alike.
- **SwiftDWG 0.2.0.** R14 lightweight polylines and hatches are read instead of coming through empty, and one that cannot be read is counted as unreadable (SwiftDWG#12), so `DrawingLoader` gives their geometry and its warnings say what was lost.


**A JWW reads at full size, with its dimensions ([#67](https://github.com/SecondMouseAU/OCCTSwiftIO/issues/67)).** `DrawingLoader` read a JWW at the size it is drawn on the sheet and with no dimensions. SwiftJWW's DXF writer wrote each element as drawn, so a part drawn at 1:80 came in at one eightieth of its size with nothing to say so, and it wrote each dimension as loose lines and text. SwiftJWW 1.4.0's writer can do both, and this package now asks it to.

- **Full size.** Each element is multiplied by the scale of its own layer group (`DXFWriter.Options(fullSize: true)`). `DrawingResult.layerGroupScales` states the scale of each layer group that holds part of the drawing. A group that states no usable scale is read at drawn size, with a `.scaleNotStated` warning. Groups at different scales give a `.mixedScales` warning: each is at its own full size, so they no longer sit relative to each other as on the sheet.
- **Rebuilt dimensions.** Many Jw_cad drawings keep a dimension as loose pieces (a dimension line, extension lines, two arrow points and the value) marked with Jw_cad's dimension flags. SwiftJWW pairs each value with the arrow points whose distance gives it and writes the pair as a `DIMENSION` (`recoversDimensions: true`). They come back as `.dimension` entities, and `DrawingResult.rebuiltDimensions` lists their identities, so a consumer can tell an inferred dimension from one stored in the file. A value it cannot explain (a radius, a diameter, an angle, or a value with no arrow points at the stated distance) stays a loose text, is listed in `DrawingResult.unexplainedDimensionValues` with its position at full size, and has an `.unexplainedDimensionValue` warning. A dimension stored as a record comes back as a `.dimension` when the file is version 4.20 or later; in an older file the record has no measured points, SwiftJWW writes it as a loose line and text, and its value is listed and warned about the same way. Which pieces each dimension was built from is not recorded yet ([SwiftJWW#22](https://github.com/SecondMouseAU/SwiftJWW/issues/22)).
- **`ShapeLoader` reads a JWW the same way.** `.jww` now goes through the same read and the same drawing-to-edges step as DXF and DWG, so the compound is at full size, block references are expanded, and `ShapeLoadResult.warnings` is what `DrawingLoader` gives for the file. A dimension written as a `DIMENSION`, stored or rebuilt, is annotation and has no edges, as for a DXF; the lines of one that is not (a value nothing explains, or a record from a file older than 4.20) stay lines. The old JWW-only mapping in `JWWLoader`, which drew every dimension's lines as edges and did not expand blocks, is removed.
- **Solid fills are reported.** SwiftJWW skips a JWW solid fill (`CDataSolid`) and only counts it. Both loaders now give a `.skippedEntities` warning for `SOLID` with that count and no layer, as a DXF `SOLID` gets one, where before nothing said so. A solid fill inside a block is dropped by SwiftJWW without being counted, so it is still not reported ([SwiftJWW#24](https://github.com/SecondMouseAU/SwiftJWW/issues/24)).
- **Breaking.**
  - Every JWW comes back at full size, which for a drawing at 1:80 is 80 times what it was. A consumer that scaled a JWW itself has to stop.
  - `ShapeLoader`'s compound for a JWW changes beyond its size: the geometry inside block references is now in it, and the lines of a dimension written as a `DIMENSION` are not.
  - JWW layers are named `<group>-<layer>` in hexadecimal (`0-E`), as Jw_cad names them in its own exports, not by the bare layer number (SwiftJWW 1.4.0). A consumer that matched the old names has to change.
  - `DrawingWarning.Kind` gains `scaleNotStated`, `mixedScales` and `unexplainedDimensionValue`, so an exhaustive `switch` over it needs them.
  - `DrawingResult` gains `rebuiltDimensions`, `unexplainedDimensionValues` and `layerGroupScales`. Its initialiser takes them as defaulted parameters, so existing calls compile.
- **SwiftJWW moves to `from: "1.4.0"`**, which has the writer options and `DXFWriter.output` with its report.
- **Known limits.** Loose dimension pieces inside a JWW block are not rebuilt, and an older dimension record inside a block is not listed (both are scanned at the top level only). An elliptical arc with a negative sweep may be drawn as the rest of its ellipse, because SwiftJWW's writer does not reorder its ends as it does for a circular arc ([SwiftJWW#23](https://github.com/SecondMouseAU/SwiftJWW/issues/23)); the removed JWW-only mapping drew it correctly on the shapes path, and `DrawingLoader` already had this before. None of the 24 ellipses in the three drawings checked has a negative sweep.
- **Tests.** `JWWFullSizeTests` writes JWW files in the test: a plate drawn at 1:10 with one dimension kept as loose pieces and a radius value nothing explains, the same width as a stored dimension record in a version 7.00 file and in a version 3.51 file, a block placed in a group at 1:10, a solid fill, two layer groups at different scales, and a group that states no scale, alone and beside a scaled one. Three JWW files join the test that holds the shapes path's warnings equal to `DrawingLoader`'s. Two real drawings are checked where they are on the machine: the JNR 2120 (1:80) gives 29 rebuilt dimensions and no unexplained value, each within one unit of its label's last digit, and dd12 (1:80) gives 14 with two unexplained values, `5,186.6` and `838.2φ`. Those tests, and the existing dd12 extent test, are skipped where the file is absent. The dd12 extent test used to wrap its expectations in a known issue, which turned a real failure into a pass; it now fails like any other test, and expects 80 times the extent it had.

**`ShapeLoader` fits a DXF or DWG spline or ellipse to lines and circular arcs, instead of flattening it to chords ([#75](https://github.com/SecondMouseAU/OCCTSwiftIO/issues/75)).** A spline was flattened to a chain of straight edges, and an ellipse to a fixed 48 chords whatever its size or shape, with no stated tolerance. Both now go through SwiftDXF's `Entity.fitted(tolerance:)`, the fit `Drawing.contours` makes, and its pieces become edges by the same conversion `loadContours` uses. The tolerance is the one splines already had, one ten-thousandth of the drawing's diagonal in the drawing's own units. A spline that is exactly a line or an arc is one edge of that kind, and a circle drawn as an ellipse is two arcs.

**This changes what `ShapeLoader` returns for a DXF or DWG with a spline or an ellipse:** fewer edges, and arcs among them. A consumer that counts edges, or assumes every edge is straight, sees the difference. Measured:

- `spline.dxf` (in the repo): 105 edges, all lines, become 23: one line and 22 arcs.
- A third-party part drawing with 465 splines (not in the repo): 23,379 edges become 4,767. The splines go from 19,468 chords to 856 pieces, 30 of them exactly lines or arcs. The farthest a new edge lies from its spline, against a dense reference, is 0.027 where the tolerance is 0.055.
- Ellipses, major radius 1 to 1000 and ratio 0.1 to 1: the 48 chords strayed 7.6 to 10 times the tolerance. The fit takes 2 to 29 pieces and stays within 0.52 times it.

Decisions on the issue's five questions: the tolerance is unchanged; ellipses are fitted as well as splines; the tolerance is not exposed; a fit that misses its tolerance is not reported (a new `DrawingWarning` case would break an exhaustive `switch` in a consumer); it is the default, not an option. The JWW loader is unchanged and still samples an ellipse as 48 chords.

**The `OCCTSwiftIO` target no longer depends on `MeshIO` ([#29](https://github.com/SecondMouseAU/OCCTSwiftIO/issues/29)).** Nothing under `Sources/OCCTSwiftIO` or `Tests/OCCTSwiftIOTests` imports `MeshIO`, so the dependency only made every consumer of the `OCCTSwiftIO` product compile the mesh-format stack behind it: ThreeMF (and so C++ `pugixml` and C++ interoperability), SwiftGLTF, SwiftPMX and SwiftX. The `MeshIO` product is unchanged and still available on its own. No source change for a consumer of either product; a consumer that relied on `OCCTSwiftIO` to bring `MeshIO` in must now name the `MeshIO` product itself. `README.md` and `docs/index.md` no longer say `OCCTSwiftIO` builds on `MeshIO`.

## v2.0.0-beta.9 (2026-11-16)

**Pre-release, pinned exactly to OCCTSwift 4.0.0-beta.6.** A consumer only gets this by naming it; the stable line stays at v1.8.0.

**`ShapeLoader` expands block references on a DXF and a DWG, and reports what it left out ([#70](https://github.com/SecondMouseAU/OCCTSwiftIO/issues/70)).** The shapes path read a drawing without expanding its `INSERT`s and had nowhere to say so, so a drawing whose geometry sits in blocks came back looking complete and nearly empty. On four real DWGs (the measurements are in the issue) it lost 8 %, 39 %, 42 % and 44 % of the curves; on the railway drawing the part's own outline, an axle placed three times, was among them. Two changes, the issue's option 3:

- **Blocks are expanded.** DXF and DWG are read with `DXF.ReadOptions(expandBlocks: true)`, as `DrawingLoader` reads them, so the geometry inside a block reference is in the compound, placed as the reference places it. This changes what a DXF with blocks loads: it now has more edges, the ones it was missing. A DXF with no blocks is unchanged.
- **`ShapeLoadResult.warnings: [DrawingWarning]`.** New, defaulted to `[]`, so source compatible. For DXF and DWG it is `DrawingLoader.warnings(...)` for the same read: entities of a type with no entity form (`SOLID`, `ATTDEF`, ...) by type and layer, entities and records a DWG could not read, a block that is missing, cyclic or nested too deep, paper space, an undeclared unit, an empty drawing. The shapes path and `DrawingLoader` now say the same about a file, and a test holds them equal on every drawing it has. Other formats leave it empty; JWW does not report yet ([#67](https://github.com/SecondMouseAU/OCCTSwiftIO/issues/67)). Text, dimensions, hatches and leaders are read but have no edges, by design, and are not warnings.

The tests use a DXF written in the test, with a block inserted three times and one that names no block. The DWG fixtures hold no curve in a block, so for a DWG the tests check that the references are expanded (the five `INSERT`s of `anonymous-names.dwg` are placed and their five `ATTDEF`s counted) and that its warnings equal `DrawingLoader`'s; a DWG with block geometry is not tested here. `docs/reference/CADFileFormat.md` listed neither `dxf` nor `dwg`; both are there now.

## v2.0.0-beta.8 (2026-11-15)

**Pre-release, pinned exactly to OCCTSwift 4.0.0-beta.6.** A consumer only gets this by naming it; the stable line stays at v1.8.0.

**`CADFileFormat.dwg`: `ShapeLoader` loads a DWG as one compound of edges ([#58](https://github.com/SecondMouseAU/OCCTSwiftIO/issues/58), "also worth deciding").** `ShapeLoader.load(from:format: .dwg)` reads the DWG in process through SwiftDWG and builds the same compound of curve edges `DXFLoader` builds for a DXF (lines, arcs, circles, ellipses, polylines and splines in the z = 0 plane; text, dimensions, hatches and leaders have no edges). `CADFileFormat(fileExtension: "dwg")` now gives `.dwg`. The drawing-to-shapes step is shared with DXF (`DXFLoader.shapes(of:)`), so the two formats cannot drift apart, and the same plate read from a DWG and from a DXF gives the same edges and bounds. A bad file throws `DWG.Error`, as `DWGLoader` does.

- **Breaking, as the beta.6 entry said it would be: `CADFileFormat` gains a case**, so an exhaustive `switch` over it needs `.dwg`. This package has none outside `ShapeLoader`; a consumer's (OCCTSwiftTools, for one) needs the case. The OCCTSwift pin does not move, so this stays a pre-release.
- **Limit, the same as DXF's: block references are not expanded, and nothing is reported.** A `ShapeLoadResult` has nowhere for warnings, so an entity SwiftDWG could not read, or an `INSERT` left unexpanded, is not said anywhere on this path. A DWG whose geometry sits in blocks (the mechanical sheet in #56 has 132 references) loads close to empty. `DrawingLoader`, which expands blocks by default and reports what it left out, is the call for those. Expanding blocks on the shapes path, for DXF as well as DWG, would change DXF's behaviour and is not done here.

## v2.0.0-beta.7 (2026-11-15)

**Pre-release, pinned exactly to OCCTSwift 4.0.0-beta.6.** A consumer only gets this by naming it; the stable line stays at v1.8.0.

**A STEP assembly loads as its leaves, not as its root as well ([#41](https://github.com/SecondMouseAU/OCCTSwiftIO/issues/41)).** `ShapeLoader` read a STEP file through `Document.shapesWithColors()`, which returns every node that has a shape. An assembly's root holds the compound of everything below it, so it came back beside the children that make it up: a three-solid assembly gave four bodies, one of them a compound of all three, and every triangle was drawn twice, picked twice and counted twice. The loader now walks the assembly tree and returns one entry per leaf, with the leaf's colour and its placement in the assembly. A component that is itself an assembly is split into its solids (the XCAF reference reports no children of its own, only the compound of its parts), and each takes the component's colour. An assembly whose children give no shape, and a compound that is the only thing in the file, are still loaded, as the model. The change affects STEP only; STL, OBJ, BREP and IGES were not affected. A caller that read the root as a body, to get the whole assembly as one shape, now gets its leaves.

## v2.0.0-beta.6 (2026-11-14)

**Pre-release, pinned exactly to OCCTSwift 4.0.0-beta.6.** A consumer only gets this by naming it; the stable line stays at v1.8.0.

**Builds on a fresh resolve again ([#60](https://github.com/SecondMouseAU/OCCTSwiftIO/issues/60)).** v2.0.0-beta.5 asked for SwiftDXF `from: "0.3.0"`, which SwiftPM resolves to the newest 0.x, and SwiftDXF 0.4.0's new `DXF.Entity` cases (`.hatch`, `.leader`) made `DXFLoader`'s `switch` non-exhaustive, so beta.5 did not compile for a consumer that did not constrain SwiftDXF. The floor is now `from: "0.4.0"` and the loader handles the new cases. This release also adds `DrawingLoader` (DXF, DWG and JWW through one entry point) and reads DWG in process through the new SwiftDWG dependency, with no converter to build or find.

**One entry point for 2D drawing import: `DrawingLoader.read(from:options:)` ([#54](https://github.com/SecondMouseAU/OCCTSwiftIO/issues/54)).** DXF, DWG and JWW come back as one `DrawingResult`: the SwiftDXF `DXF.Drawing`, a `DrawingSource` (file name, SHA-256, format and the format's own version) and `DrawingWarning`s as data (skipped entities by type and layer, entities and records a DWG could not read, paper space, missing or cyclic blocks, entities a non-uniform scale could not carry, undeclared units, an empty drawing). The format is told from the file's bytes (`DrawingFormat.sniff`), with the extension consulted only when the bytes say nothing. JWW is read by SwiftJWW and passed through its DXF writer, so a JWW insert expands like a DXF one. Block references are expanded by default (`Options.expandBlocks`), with the references recorded in each entity's identity. `DXFLoader.readEntities(from:options:)` and `DWGLoader.readEntities(from:options:)` take SwiftDXF's `DXF.ReadOptions`. The hash helper is shared (`FileDigest`).

**DWG tests on files AutoCAD wrote ([#58](https://github.com/SecondMouseAU/OCCTSwiftIO/issues/58) item 3).** `Fixtures/DWG/autocad/` holds small drawings saved by AutoCAD (AC1027 and AC1032), including a DWG with the DXF AutoCAD wrote from the same drawing, taken unmodified from the acadrust repository, where they are published under MPL-2.0 (the licence and the origin are in that folder). They test the reader on files it did not write itself: the line end points, the linear dimension's definition points and rotation, the handles AutoCAD gave (`2C1`, `2C2`, `2C3`) and the names of anonymous blocks, each as the files' author documents them, and the DWG's tables against AutoCAD's own DXF of it. AC1009 to AC1024 still have no independent fixture here (SwiftDWG's own tests cover its releases).

**SwiftDXF moves to `from: "0.4.0"`.** 0.4.0 carries the work behind #55, #56, #57 and #59 (see its README): `DIMENSION` rotation, a computed measurement and `measurement` that is `nil` when group 42 is absent, zero or negative (it was `-1.0` for SolidWorks and McMaster files; use `computedMeasurement` for the value), the dimension style's precision and the text split into parts; `Drawing.identities` (the DXF handle, else the position); block references, the layer and line type tables and per-entity line types; `Entity.fitted(tolerance:)` for splines and ellipses; and the extrusion of arcs, circles and polylines applied. `DXF.Entity` gains `.hatch` and `.leader`, and `DXF.Warning` gains `.extrusionNotApplied` and `.expansionTruncated`, so an exhaustive `switch` over either needs the new cases: `DXFLoader` ignores hatches and leaders (no edges), and `DrawingWarning.Kind` gains `extrusionNotApplied` and `expansionTruncated`. HATCH and LEADER no longer appear in `skipped`. Identities no longer carry a `#` (`31`, `A1/C1`).

**Tests.** The same 100 x 60 plate is read from a DXF (`Fixtures/Drawing/plate.dxf`), the DWG and a JWW generated at test time (`Support/JWWFixture.swift`), and the three have the same lines and circle.

**DWG: Tools/dwg2dxf is gone, SwiftDWG reads it in process ([#58](https://github.com/SecondMouseAU/OCCTSwiftIO/issues/58) item 1).** `DWGLoader.readEntities(from:options:)` returns a `DWGLoader.Conversion`: the drawing in the same SwiftDXF entity model `DXFLoader.readEntities` returns, the source's SHA-256 and DWG version code, and `warnings` (what the reader could not read, an empty result). It reads through [SwiftDWG](https://github.com/SecondMouseAU/SwiftDWG) (`from: "0.1.0"`, MIT, which needs SwiftDXF 0.4.0 or later), a Swift port of ACadSharp's DWG reader with the Open Design Alliance's specification. No subprocess, no Rust toolchain, no tool to find at run time, and not macOS-only. `Tools/dwg2dxf` (the Rust crate on acadrust), `OCCTSWIFTIO_DWG2DXF` and the cargo build and cache steps in `tests.yml` are removed, and the DWG tests, which took a known-issue path without the converter, run unconditionally. `import OCCTSwiftIO` re-exports SwiftDWG's `DWG` namespace, as it does SwiftDXF's `DXF`, because a bad DWG throws `DWG.Error`.

- **Breaking, against main; none of it was in a release.** `DWGLoader.readEntities(from:converter:options:)` loses `converter:`. Removed: `DWGLoader.locateConverter`, `DWGLoader.converterEnvironmentVariable`, `DWGLoader.DWGError` (catch `DWG.Error`: `.notADWG`, `.unsupportedVersion`, `.truncated`, `.invalid`) and `DWGLoader.Conversion.converter`.
- **Not breaking against main: `DrawingLoader.Options.converter`, `DrawingSource.converter` and `DrawingWarning.Kind.converter`.** They exist only in the unmerged DrawingLoader change (#61); this change removes them before they land, because with no converter there is nothing to record in them and a field that is always `nil` would only mislead. `DrawingSource` records the file, its hash, its format and the format's version.
- **The reader now runs in your process.** The subprocess contained whatever went wrong inside the converter. SwiftDWG 0.1.0 ends a corrupt file in a `DWG.Error` or in a drawing that counts what it lost, and is not meant to trap or never return; its README says that is checked by inverting sampled bytes of its committed drawings and of the AutoCAD samples, and not proved for every byte, so a file found to trap or hang is a bug to report. A pipeline that reads DWGs it does not trust can still run the reader out of process.
- **New: `DrawingWarning.Kind.unreadable`.** SwiftDWG leaves out an entity, table record or block it cannot read and counts it in `skipped` as `UNREADABLE_<type>`. `DrawingLoader` reports each type as `.unreadable` (`type` without the prefix, `OBJECT` when the object has no readable type) and no longer reports it as `.skippedEntities` or as paper space. Blocks that are not expanded (`expandBlocks: false`) are counted too. A file damaged in its structure, such as an unreadable layer, line type, text style, dimension style or block control object, throws `DWG.Error` and is not wrapped.
- **Changed: a DWG's skipped entities have no layer.** SwiftDWG writes the entities it does not model, and the ones it could not read, as bare records, so SwiftDXF counts them on layer `0` (on the layer of the `INSERT`, in a block that was expanded) whatever their layer was. `DrawingWarning.layer` is `nil` for a DWG, and there is one `.skippedEntities` warning per type.
- **Changed: releases read.** SwiftDWG reads R2000 to R2018, and R14 for simple entities. R12 and earlier throw `DWG.Error.unsupportedVersion`; the converter's documentation said AC1009 and later, though no fixture of those releases was ever tested.
- **Unchanged: `CADFileFormat` has no `.dwg` case** and `ShapeLoader` does not load DWG: it is an entity-level read through `DrawingLoader` and `DWGLoader`. Adding the case is source-breaking for an exhaustive `switch` and needs a shapes path for DWG (the DXF one reads a file, not a drawing); it is left to the maintainer ([#58](https://github.com/SecondMouseAU/OCCTSwiftIO/issues/58), "also worth deciding").
- **Tests.** The two AutoCAD-written DWGs and the pair (`point_object_id.dwg` and the DXF AutoCAD wrote from it) from the previous entry now read through SwiftDWG, and the pair agrees on the layer, line type and dimension style tables, handles included. A truncated, damaged or newer-release file throws `DWG.Error` from both loaders, and a non-DWG does from `DWGLoader` (from `DrawingLoader` when the file is named `.dwg`), a sample of single inverted bytes of two DWGs ends in a drawing or a `DWG.Error` and never in a crash, and what SwiftDWG cannot read comes through as `.unreadable`.

## v2.0.0-beta.5 (2026-10-24)

**Pre-release, pinned exactly to OCCTSwift 4.0.0-beta.6.** Shipped without an entry here; this one is written afterwards from the tag (`0695776`). It does not compile on a fresh resolve, because of SwiftDXF 0.4.0 ([#60](https://github.com/SecondMouseAU/OCCTSwiftIO/issues/60)); use v2.0.0-beta.6.

**DXF closed regions as planar faces, on SwiftDXF 0.3.0.** The SwiftDXF dependency moves from `from: "0.2.0"` to `from: "0.3.0"`, which adds `DXF.Entity.spline` (source-breaking for any exhaustive `switch` over `DXF.Entity`; this package's loader is updated) and the OCCT-free contour layer (`drawing.contours`). The OCCTSwift pin is unchanged.

- New `DXFLoader.loadContours(from:options:)` and `DXFLoader.contourFaces(of:options:)` return a `DXFContourResult`: one `DXFContourFace` (face, outer wire, hole wires, analytic area, source contour) per closed region, plus SwiftDXF's `warnings`, `openChains`, `unit`, `unitScale` and `maxFitDeviation` as data, and `shapeLoadResult` for `ShapeLoader` consumers. Chaining, nesting, unit conversion and ellipse/spline fitting stay in SwiftDXF; this package only builds OCCT edges, wires and faces. Arcs are true circular arcs, lines are lines.
- `DXFLoader.load(from:)` and `ShapeLoader` behave as before (one compound of edges). `SPLINE` now loads in that path, flattened to straight edges at one ten-thousandth of the drawing diagonal; ellipses are still polylined. Bulged polyline arcs now share the contour segment geometry.
- Tests copy ezdxf-generated fixtures from SwiftDXF's test suite into `Tests/OCCTSwiftIOTests/Fixtures/DXF`.

## v2.0.0-beta.4 (2026-10-17)

**Pre-release, pinned exactly to OCCTSwift 4.0.0-beta.6.** A consumer only gets this by naming it; the stable line stays at v1.8.0.

Moves the OCCTSwift dependency from `exact: "4.0.0-beta.5"` to `exact: "4.0.0-beta.6"`. No source change: the package builds and all tests pass unmodified against beta.6. Nothing in beta.6's breaks (`simd` removed from the public surface, `offsetWire` sign, `circularPattern` partial-angle stepping) reaches this package's call sites.

## v2.0.0-beta.3 (2026-10-10)

**Pre-release, pinned exactly to OCCTSwift 4.0.0-beta.5.** A consumer only gets this by naming it; the stable line stays at v1.8.0.

Moves the OCCTSwift dependency from `exact: "4.0.0-beta.4"` to `exact: "4.0.0-beta.5"`. No source change: the package builds and all tests pass unmodified against beta.5. Nothing in beta.5's three breaks (`Shape.isEmptyShape` removed, `Shape.analyze(tolerance:)` wire ordering, `Shape.solid(from:)` on an open body) reaches this package's call sites.

## v2.0.0-beta.2 (2026-09-30)

**Pre-release. Same code as v2.0.0-beta.1; use this tag instead.** v2.0.0-beta.1 was cut at `ccf49c3`, then
deleted and recreated at `39abfc9` to fix the OCCTSwift pin (see below). Moving a published tag changes the commit
a version resolves to, so a consumer who had already resolved beta.1 gets a SwiftPM fingerprint mismatch
("does not match previously recorded value") on their next resolve
([#46](https://github.com/SecondMouseAU/OCCTSwiftIO/issues/46)). beta.2 carries the exact same tree as the
current beta.1 (`39abfc9`) under a tag that has only ever pointed at one commit. Published tags, pre-releases
included, are not moved or deleted from here on; a fix ships as the next number.

## v2.0.0-beta.1 (2026-09-29)

**Pre-release, pinned exactly to OCCTSwift 4.0.0-beta.4.** A consumer only gets this by naming it; the stable line stays at v1.8.0.

**`ShapeLoadResult`'s GD&T element types change (breaking).** OCCTSwift 4.0.0 replaces the untyped
`DimensionInfo`, `GeomToleranceInfo` and `DatumInfo` with the typed `Document.Dimension`,
`Document.GeomTolerance` and `Document.Datum` ([OCCTSwift#996](https://github.com/SecondMouseAU/OCCTSwift/issues/996)).
`ShapeLoadResult.dimensions`, `.geomTolerances` and `.datums`, and their initializer parameters, now use the
new types, so the major version moves. `Document.Dimension.value` is `Double?` and a range dimension reports
its bounds through `.bounds`, so code that read the old flat fields needs to switch on `bounds`.

**Dep bump:** `OCCTSwift from: "3.0.0"` to `exact: "4.0.0-beta.4"`. Exact, not `from:`, because `v4.0.0-kernel.N` tags are pre-releases of the same package that sort above every beta, so `from: "4.0.0-beta.4"` resolves to the newest kernel tag (main's source) rather than the beta. The other OCCTSwift 4.0.0 breaks
(`docs/SEMVER.md#v400`) have no call sites in this repo. Verified: `swift build --build-tests` clean and the
full suite passes against the real beta.4 checkout.

## v1.8.0 (2026-08-21)

**New public type: `DirectoryWatcher`.** Watches a file or directory for create/modify events
and invokes a caller-supplied closure, backed by kqueue. Closes [#42](https://github.com/SecondMouseAU/OCCTSwiftIO/issues/42).

The agent-viewport selection bridge (`SecondMouseAU/ecosystem#53`) needs both an interactive
host and an MCP tool to notice a changed sidecar JSON file without polling on a fixed timer. The
only existing implementation of this technique in the ecosystem was `ScriptWatcher.swift`
(kqueue-based, macOS-only), living in `OCCTSwiftViewport`'s demo app rather than as a public
library component. `DirectoryWatcher` ports that proven approach into a standalone type with no
Viewport dependency, so `OCCTMCP`, `OCCTSwiftInteraction`, and (transitively) `OCCTSwiftUX` can
all depend on it without a new dependency edge.

Two behaviors go beyond a bare kqueue wrapper:

- Starting on a path that does not exist yet is not an error: the watcher falls back to
  watching the nearest existing ancestor directory, then switches to watching the target
  directly once it is created.
- When the watched path is a directory, dotfile entries (names starting with `.`) are ignored,
  so a write-to-hidden-temp-name-then-rename-into-place sequence (`.incoming-x.json` renamed to
  `x.json`) produces exactly one notification, for the final name.

macOS-only: kqueue is a Darwin primitive, and this package's platform floor also spans
iOS/visionOS/tvOS, so the whole file is gated `#if os(macOS)`. `Package.swift`'s platform floor
is unchanged; the type is simply absent on the other three platforms.

## v1.7.8 (2026-08-19)

**Repin OCCTSwift floor to 3.0.0.** OCCTSwift's v3.0.0 ([`docs/SEMVER.md#v300`](https://github.com/SecondMouseAU/OCCTSwift/blob/v3.0.0/docs/SEMVER.md#v300)) is a Rule 2 major on a much smaller surface than v2.0.0. OCCT itself does not move: the kernel stays at 8.0.1, rebuilt as `v3.0.0-kernel.1` to carry two patches the v2.0.0 asset was missing ([#905](https://github.com/SecondMouseAU/OCCTSwift/issues/905)/[#913](https://github.com/SecondMouseAU/OCCTSwift/issues/913)). Three breaks, all compile errors, audited against every call site here ([#38](https://github.com/SecondMouseAU/OCCTSwiftIO/issues/38)):

- `Selector.SubShapeType.compsolid` renamed `.compSolid`, and `Shape.ShapeFilterType.RawValue` moving from `Int32` to `Int` as `ShapeFilterType` becomes a `ShapeType` typealias (both [#844](https://github.com/SecondMouseAU/OCCTSwift/issues/844)): zero hits in this repo.
- `Shape.bounds`/`size`/`center`, `Wire.bounds`, `Edge.bounds` and `Face.bounds`/`exactBounds` became Optional ([#943](https://github.com/SecondMouseAU/OCCTSwift/issues/943)), so a void bounding box stops fabricating `(0,0,0)-(0,0,0)`. This one bit, in the **test target only**: `DXFLoaderTests` (two sites) and `JWWLoaderTests` (one) read `shape.bounds` on a loaded compound. Each now unwraps through the `try #require` it already sat behind, deliberately not `?? .zero`, because a void bounding box has to fail the assertion rather than read as a zero-size drawing at the world origin.

Worth recording for the rest of the fanout: `swift build` alone reports this repin clean, because it does not compile test targets. The break only surfaces under `swift build --build-tests` or `swift test`.

`Sources/` never reads any of the six accessors, so the shipped library is unchanged: no public API or behaviour change here, and consumers need no migration.

## v1.7.7 — 2026-08-10

**Repin OCCTSwift floor to 2.0.0.** OCCTSwift's v2.0.0 ([`docs/SEMVER.md#v200`](https://github.com/SecondMouseAU/OCCTSwift/blob/main/docs/SEMVER.md#v200)) is a correctness major (Pass 1a/1b duplication+bug-fix audit, [#377](https://github.com/SecondMouseAU/OCCTSwift/issues/377)/[#669](https://github.com/SecondMouseAU/OCCTSwift/issues/669); OCCT absorbed to 8.0.1), 17 breaking API changes (12 compile errors, 5 silent value changes). Audited this package's call sites against the full break table, including the sub-shape-enumeration (#541/#568/#613/#502) and AAG (#642/#699) families a first-pass grep at issue-filing time hadn't covered: zero hits anywhere. `Sources/OCCTSwiftIO/ShapeLoader.swift`'s `subShapes(ofType: .solid)` was already `TopExp::MapShapes`-backed and deduplicated before this release, the exact convention #502 generalized elsewhere, not something that changed under it. Ecosystem-wide floor bump; no API or behaviour change here.

## v1.7.6 — 2026-07-30

**Repin OCCTSwift floor to 1.17.0.** Picks up Pass 1a of OCCTSwift's [#377/#380](https://github.com/SecondMouseAU/OCCTSwift/issues/377) duplication/bug-fix audit: nine duplicated continuity enums consolidated into two (source-compatible via deprecated-alias shims), several dedup cleanups, and edge-case bug fixes (arc-length failure sentinels, `Surface.normal` at singularities, `Curve2D.circle` at radius zero). One real API break — `Surface.drawMesh`/`evaluateGrid` now return a `SurfaceGrid` struct instead of `[[SIMD3<Double>]]` — is unused in this repo (grep-verified). Ecosystem-wide floor bump; no API or behaviour change here.

## v1.7.5 — 2026-07-20

**Migrate off deprecated `TopologyGraph` → `BRepGraph`.** OCCTSwift renamed its core graph class from `TopologyGraph` to `BRepGraph` in [OCCTSwift#335](https://github.com/SecondMouseAU/OCCTSwift/pull/335) (v1.15.0), keeping a deprecated `typealias TopologyGraph = BRepGraph` for source compatibility. Closes [#27](https://github.com/SecondMouseAU/OCCTSwiftIO/issues/27).

`Sources/OCCTSwiftIO/MLExport.swift`'s `extension TopologyGraph { ... }` (the `exportForML()` / `exportJSON()` / `GraphExport` ML export layer) now reads `extension BRepGraph`, plus the matching test suite (`BRepGraphMLExportTests`) and docs. No public API or behaviour change: `TopologyGraph` remains callable (deprecated, with a compiler warning) since it names the same underlying type; this just stops OCCTSwiftIO's own source from routing through the deprecated name.

Also fixed a pre-existing doc bug in `docs/guides/cookbook/ml-export.md` and `docs/reference/GraphExport.md`: both called a `shape.topologyGraph()` convenience method that has never existed on `Shape` in OCCTSwift (the same bug was independently caught and fixed upstream in OCCTSwift's own docs the same day, commit `cf57630`). Examples now use the real, failable `BRepGraph(shape:)` initializer.

OCCTSwift dependency floor (`from: "1.12.9"`) already permits 1.15.0 as an open semver range — no `Package.swift` change needed. Verified building and testing against OCCTSwift 1.15.0 via a refreshed `Package.resolved`.

## v1.7.4 — 2026-07-20

**Repin OCCTSwift floor to 1.12.9.** OCCTSwift v1.12.8 added kernel patch 0006 (a `BRepGProp_EdgeTool` null-curve-on-surface guard, [OCCTSwift#318](https://github.com/SecondMouseAU/OCCTSwift/issues/318)) and v1.12.9 added patches 0007 through 0009 (free-bounds `lwire` reset, boolean-path BSpline O(1) periodic normalization, and STEP-writer oversized-string split; [OCCTSwift#323](https://github.com/SecondMouseAU/OCCTSwift/issues/323)), on top of the earlier fillet, free-bounds, and ShapeFix_Face patches. Ecosystem-wide floor bump; no API or behaviour change.

## v1.7.3 — 2026-07-19

**Repin OCCTSwift floor to 1.12.7.** OCCTSwift v1.12.7 carries OCCT kernel patch 0005: `ShapeFix_Face::FixPeriodicDegenerated` guards a null `Context()`, fixing the SIGSEGV in [OCCTSwift#317](https://github.com/SecondMouseAU/OCCTSwift/issues/317) (upstream [OCCT#1380](https://github.com/Open-Cascade-SAS/OCCT/pull/1380)), on top of the free-bounds (#310) and thread-safe-fillet (#298) patches. Ecosystem-wide floor bump so no consumer transitively resolves a pre-fix OCCTSwift. No API or behaviour change.

## v1.7.2 — 2026-07-19

**Repin OCCTSwift floor to 1.12.6.** OCCTSwift v1.12.6 carries OCCT kernel patch 0004 — `ShapeAnalysis_FreeBounds` no longer returns a null `owires` on empty input, fixing the uncatchable free-bounds SIGSEGV ([OCCTSwift#310](https://github.com/SecondMouseAU/OCCTSwift/issues/310), upstream [OCCT#1377](https://github.com/Open-Cascade-SAS/OCCT/pull/1377)) — on top of the thread-safe-fillet patch 0003 (#298). Ecosystem-wide floor bump so no consumer transitively resolves a pre-fix OCCTSwift. No API or behaviour change.

## v1.7.1 — 2026-07-18

**Repin OCCTSwift floor to 1.12.3.** OCCTSwift v1.12.3 fixes non-reentrant 3D fillet/chamfer statics in the OCCT kernel (carried patch 0003 — [OCCTSwift#298](https://github.com/SecondMouseAU/OCCTSwift/issues/298) / upstream [OCCT#1374](https://github.com/Open-Cascade-SAS/OCCT/pull/1374)): concurrent fillet builds no longer corrupt each other into wrong-but-plausible solids. Ecosystem-wide floor bump so no consumer of this package can transitively resolve a pre-fix OCCTSwift. No API or behaviour change here.

## v1.7.0 — 2026-07-18

**`ShapeLoader` splits a multibody file into one entry per body.** Closes [#21](https://github.com/SecondMouseAU/OCCTSwiftIO/issues/21).

OCCTSwift v1.11.3 fixed a silent data-loss bug in the robust importers: before it, `loadSTLRobust`
(and `loadRobust` / `loadWithDiagnostics`) dropped every body after the first, so a 10-body file came
back as 1 solid ([OCCTSwift#302](https://github.com/SecondMouseAU/OCCTSwift/issues/302)). It now returns
a **compound of solids** for a multibody file, a plain **solid** for a single-body one.

`ShapeLoader`'s STL / OBJ / BREP / IGES paths wrapped whatever they got in a **single** `shapesWithColors`
entry, so post-fix they lumped a whole compound-of-solids into one entry — inconsistent with the STEP
path, which has always returned one entry per body via `Document.shapesWithColors()`. A consumer got N
bodies from a STEP assembly but 1 lumped body from the equivalent STL, collapsing per-body selection,
colour and metadata.

**Change:** these paths now return **one entry per body**. A `.solid` result stays a single entry; a
compound is split into its solids; a result with no solids (a raw-mesh STL that loaded as loose faces)
stays a single entry. No API change — same `shapesWithColors` shape, more entries.

Minimum OCCTSwift bumped to **1.11.3** (the split has nothing to split without the #302 fix).

## v1.6.0 — 2026-07-16

**`MeshIO.Mesh` carries PMX material groups.** Closes [#17](https://github.com/gsdali/OCCTSwiftIO/issues/17).

Previously `MeshIO`'s PMX adapter discarded SwiftPMX 1.1.0's `Mesh.submeshes` — the material section's
per-material index ranges — so a consumer had no way to isolate one part of a whole-model PMX (e.g. a
vehicle's carbody skin out of the full fused mesh) without bypassing `MeshIO` and consuming `SwiftPMX`
directly.

**New public API** (additive; existing consumers unaffected):

- `struct Submesh` — `indexOffset` / `indexCount` / `materialIndex`, one per source-file material.
- `Mesh.submeshes: [Submesh]` — empty for formats/files with no such grouping; populated for PMX.

**Dependencies:** `SwiftPMX` bumped `from: "1.0.0"` → `from: "1.1.0"` (the release that added
`Mesh.submeshes`).

Out of scope (noted, not requested): `SwiftX` (`.x`) has the same structural gap — it fuses every
`Mesh` block in a file into one buffer with no per-block grouping exposed — but no `.x` model in the
corpus needed a sub-part isolated yet, so `MeshIO`'s `.x` adapter is unchanged.

## v1.5.0 — 2026-06-26

**New format: DXF (AutoCAD Drawing Interchange Format)** — entity-level read (geometry + TEXT + layers), alongside the existing JWW path. Closes [#11](https://github.com/gsdali/OCCTSwiftIO/issues/11).

**Entity model (primary).** `import OCCTSwiftIO` now re-exports [SwiftDXF](https://github.com/SecondMouseAU/SwiftDXF), so the neutral `DXF.Drawing` / `DXF.Entity` model is in scope directly. `DXFLoader.readEntities(from:)` returns it. The model preserves what DXF actually carries — geometry (`LINE`/`CIRCLE`/`ARC`/`ELLIPSE`/`LWPOLYLINE`/`POLYLINE` with per-vertex bulge), `TEXT`/`MTEXT` (insertion point **and** string), **per-entity layer name**, and header essentials (`$INSUNITS`, `$EXTMIN`/`$EXTMAX`).

**OCCT `Shape` convenience.** `CADFileFormat.dxf` (extension `dxf`); `ShapeLoader` also builds a compound of OCCT edges in the Z=0 plane (lines/circles/arcs/ellipses/bulged-polylines → edges; points → vertices; text skipped) — same shape as the JWW path. No B-Rep solid; the entity model, not the `Shape`, is the source of truth for DXF.

**Reader.** Pure-Swift SwiftDXF (MIT), validated bit-exact against the MIT-licensed `ezdxf` reference reader — entity counts and every coordinate scalar — across an 11-file / ~62k-entity corpus.

## v1.0.0 — 2026-05-08

OCCTSwift dependency bumped to **`from: "1.0.1"`** (OCCT 8.0.0 GA pin). No public API changes in this package — pure dep bump to graduate alongside [OCCTSwift v1.0.0](https://github.com/gsdali/OCCTSwift/releases/tag/v1.0.0). SemVer-stable from this tag.

Closes [#3](https://github.com/gsdali/OCCTSwiftIO/issues/3).

## v0.2.0 — 2026-05-07

ML-export hoist from OCCTSwift per [OCCTSwiftIO#1](https://github.com/gsdali/OCCTSwiftIO/issues/1) (supersedes [OCCTSwift#71](https://github.com/gsdali/OCCTSwift/issues/71)). The consumption-side ML repacking layer added to OCCTSwift in v0.136.0 — pure batch / headless workflow, no Viewport — fits this package's charter, so it lives here now.

**New public API** (extension on `OCCTSwift.TopologyGraph`):

- `struct GraphExport` — flat vertex positions + per-edge boundary/manifold flags + COO-format face/edge/vertex incidence + face-to-face adjacency.
- `func exportForML() -> GraphExport` — build the export from a `TopologyGraph`.
- `func exportJSON() -> Data?` — JSON serialization for ML pipelines.

**What did not move** (and why):

- `FaceGridSample` / `sampleFaceUVGrid(faceIndex:uSamples:vSamples:)` stay in OCCTSwift. Their implementation calls `OCCTBRepGraphSampleFaceUVGrid` on `TopologyGraph.handle`, which is `internal` to the OCCTSwift module — lifting them would require widening kernel visibility, which the partial-lift decision on issue #1 rules out as out-of-scope.
- `sampleEdgeCurve(edgeIndex:count:)` similarly stays — same `handle` constraint.

**Breaking change for OCCTSwift consumers:** the `TopologyGraph.exportForML / exportJSON` symbols have been deleted from OCCTSwift (kernel release coordinated separately). Direct callers must now `import OCCTSwiftIO` in addition to `import OCCTSwift`. Symbol resolution otherwise unchanged. Known callers swept: `OCCTSwiftScripts/Sources/occtkit/Commands/GraphML.swift`, `OCCTSwiftScripts/Sources/GraphML/main.swift`.

**Dependencies:** `OCCTSwift` ≥ `0.171.0` (the kernel release that ships the matching deletion).

## v0.1.0 — 2026-05-06

Initial release. Spin-out of file-I/O concerns from [OCCTSwiftTools](https://github.com/gsdali/OCCTSwiftTools) per [OCCTSwiftTools#12](https://github.com/gsdali/OCCTSwiftTools/issues/12) so headless consumers (Scripts, PadCAM CLI, batch pipelines) don't drag in `OCCTSwiftViewport` transitively just to load a STEP file.

**Public API:**

- `enum ShapeLoader` — `load(from:format:progress:)`, `loadRobust(...)`, `loadFromManifest(at:)`. Returns `ShapeLoadResult { shapesWithColors, dimensions, geomTolerances, datums, manifest }`.
- `enum CADFileFormat` — `.step`, `.stl`, `.obj`, `.brep`, `.iges` (lifted from OCCTSwiftTools).
- `enum ExportManager` + `enum ExportFormat` — OBJ / PLY / STEP / BREP / glTF / GLB writers (lifted from OCCTSwiftTools).
- `struct CADBodyMetadata` — pure-data per-body picking metadata (face / edge / vertex indices). Produced by `OCCTSwiftTools.CADFileLoader.shapeToBodyAndMetadata`; lives here so the type itself doesn't carry a Viewport dep.
- `struct ScriptManifest` — Codable manifest format for the script harness (lifted from OCCTSwiftTools).
- `final class ImportProgressClosure` — closure-backed `OCCTSwift.ImportProgress` adapter (lifted from OCCTSwiftTools).

**What's not here:**

- `ViewportBody` production. That's `OCCTSwiftTools.CADFileLoader.shapeToBodyAndMetadata` — one floor up — and is the entire reason this package exists separately.
- `CADLoadResult { bodies: [ViewportBody], ... }`. Stays in OCCTSwiftTools where the Viewport dep already lives.

**Dependencies:**

- `OCCTSwift` ≥ `0.170.1`.

**Platform floor:** iOS 18 / macOS 15 / visionOS 1 / tvOS 18 — matches OCCTSwiftTools so consumers using both don't have to reconcile floors.

**Test invocation:** `OCCT_SERIAL=1 swift test --parallel --num-workers 1`. The env var + serial workers are required, not optional, due to a known NCollection container-overflow race in OCCT on arm64 macOS.
