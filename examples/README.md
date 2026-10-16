# MetroForge test city

Download and extract `MetroForge-Test-City.zip`. In **MetroForge Godot 0.3.1**, use **City / Files → Import JSON file** and choose **MetroForge-Test-City-Complete.json** from the extracted folder.

This is a complete export from the native game: 2,704 tiles (52 × 52), population 176, jobs 222, $250,000, January 2003. It includes roads, zoning, developed properties, power, water, rail and civic services. Random disasters are disabled. Existing cities are replaced only after a valid import; save/export yours first if you want to keep it.

The ZIP keeps the JSON separate from browser/chat file previews. Its included `READ-ME.txt` records the JSON checksum. Import was checked through the native game's file-selection callback, including an export/import round trip. That desktop check does not reproduce Android's native document-provider access.
