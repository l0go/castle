package;

import sys.io.File;

import electron.main.App;
import electron.main.Dialog;
import electron.main.BrowserWindow;
import electron.main.IpcMain;

import electron.main.Menu;
import electron.main.MenuItem;

class Main {
	static function main() {
		App.whenReady().then(_ -> {
			final win = new BrowserWindow({
				webPreferences: {
					nodeIntegration: true,
					contextIsolation: false
				}
			});

			IpcMain.handle("getWindowGeometry", (event) -> {
				final size = win.getSize();
				final pos = win.getPosition();
				return {width : size[0], height : size[1], x : pos[0], y : pos[1]};
			});

			IpcMain.handle("setWindowPosition", (event, x, y) -> {
				(BrowserWindow.fromWebContents(event.sender) : BrowserWindow).setPosition(x, y);
			});

			IpcMain.handle("setWindowSize", (event, width, height) -> {
				(BrowserWindow.fromWebContents(event.sender) : BrowserWindow).setSize(width, height);
			});

			IpcMain.handle("openDevTools", (event, _) -> {
				event.sender.openDevTools(); 
			});

			IpcMain.handle("clearCache", () -> {
				(BrowserWindow.getFocusedWindow() : BrowserWindow).webContents.session.clearCache();
			});

			IpcMain.handle("popupLine", (event, enableSeparator, checkSeparator, options) -> {
				popupLine(win, enableSeparator, checkSeparator).popup(options);
			});

			IpcMain.handle("popupColumn", (event, columnType, checked, ndispEnabled, niconEnabled, options) -> {
				popupColumn(win, columnType, checked, ndispEnabled, niconEnabled).popup(options);
			});

			IpcMain.handle("popupSheet", (event, showLevelCheckbox, showLevelCheckbox, nindexChecked, ngroupChecked, nlevelChecked, options) -> {
				popupSheet(win, showLevelCheckbox, nindexChecked, ngroupChecked, nlevelChecked).popup(options);
			});

			IpcMain.handle("maximize", (event) -> {
				win.maximize();
			});

			win.on("maximize", () -> {
				win.webContents.send("maximize");
			});

			win.on("unmaximize", () -> {
				win.webContents.send("unmaximize");
			});

			IpcMain.handle("chooseFileBytes", (event, channel, images) -> {
				var filters = [];
				if (images) filters.push({name: "Filetype", extensions: ["jpeg", "png", "gif", "jpg"]});
				Dialog.showOpenDialog({
					{
						filters: filters,
						properties: ['openFile'],
					}
				}).then((response) -> {
					if (untyped response.filePaths[0] != null) {
						return {
							path: untyped response.filePaths[0],
							bytes: sys.io.File.getBytes(untyped response.filePaths[0]),
						};
					}
					return null;
				});
			});

			IpcMain.handle("saveFile", (event, saveAs, text) -> {
				var path = Dialog.showSaveDialogSync({
					defaultPath: saveAs,
					properties: ['createDirectory', 'showOverwriteConfirmation'],
				});
				if (text != null) {
					File.saveContent(path, text);
				} else {
					return path;
				}
				return null;
			});

			IpcMain.handle("exists", (event, path) -> {
				return sys.FileSystem.exists(path);
			});

			initMenu(win);

			win.loadFile(App.getAppPath() + "/index.html");
		});
	}

	static function initMenu(window: BrowserWindow) {
		var modifier = "Ctrl";
		var menu = new Menu();
		if(Sys.systemName().indexOf("Mac") != -1) {
			modifier = "Cmd";
		}

		var mrecents = new Menu();
		IpcMain.removeHandler("add-recents-file");
		IpcMain.handle("add-recents-file", (event, file) -> {
			var m = new MenuItem( { label : file } );
			m.click = () -> {
				window.webContents.send("open-recent", file);
			};
			mrecents.append(m);
		});

		var mfiles = new Menu();
		var mfile = new MenuItem({ label : "File", submenu: mfiles });

		var mnew = new MenuItem( { label : "New", accelerator : '$modifier+N' } );
		mnew.click = () -> {
			window.webContents.send("click-new");
		};

		var mopen = new MenuItem( { label : "Open...", accelerator : '$modifier+O' } );
		mopen.click = () -> {
			window.webContents.send("click-open");
		};

		var mrecent = new MenuItem( { label : "Recent Files", submenu : mrecents } );

		var msave = new MenuItem( { label : "Save As...", accelerator : '$modifier+S' } );
		msave.click = () -> {
			window.webContents.send("click-save");
		};

		var mclean = new MenuItem( { label : "Clean Images" } );
		mclean.click = () -> {
			window.webContents.send("click-clean");
		};

		var mexport = new MenuItem( { label : "Export Localized texts" } );
		mexport.click = () -> {
			window.webContents.send("click-export");
		};

		var mcompress = new MenuItem( { label : "Enable Compression", role: "checkbox" } );
		mcompress.click = function() {
			window.webContents.send("click-compression", mcompress.checked);
		};
		IpcMain.removeHandler("set-mcompress");
		IpcMain.handle("set-mcompress", (event, value) -> {
			mcompress.checked = value;
		});

		var mabout = new MenuItem( { label : "About" } );
		mabout.click = () -> window.webContents.send("click-about");

		var mexit = new MenuItem( { label : "Exit", accelerator : '$modifier+Q' } );
		mexit.click = electron.main.App.quit;

		var mdebug = new MenuItem( { label : "Dev" } );
		mdebug.click = window.webContents.openDevTools; 

		for( m in [mnew, mopen, mrecent, msave, mclean, mcompress, mexport, mabout, mexit] )
			mfiles.append(m);

		// create an edit menu
		modifier = "Ctrl+Shift";
		if(Sys.systemName().indexOf("Mac") != -1)
			modifier = "Cmd+Shift";

		var medits = new Menu();
		var medit = new MenuItem({ label : "Database", submenu : medits });
		
		var mnewsheet = new MenuItem( { label : "New Sheet", accelerator : '$modifier+N' } );
		mnewsheet.click = () -> window.webContents.send("click-new-sheet");

		var mnewcolumn = new MenuItem( { label : "Add Column", accelerator : '$modifier+C' } );
		mnewcolumn.click = () -> window.webContents.send("click-add-column");

		var mnewline = new MenuItem( { label : "Add Line", accelerator : '$modifier+L' } );
		mnewline.click = () -> window.webContents.send("click-add-line");

		var medittypes = new MenuItem( { label : "Edit Types", accelerator : '$modifier+E' } );
		medittypes.click = () -> window.webContents.send("click-edit-types");

		for(m in [mnewsheet, mnewcolumn, mnewline, medittypes])
			medits.append(m);

		menu.append(mfile);
		menu.append(medit);
		menu.append(mdebug);

		Menu.setApplicationMenu(menu);
	}

	static function popupLine(window: BrowserWindow, enableSeparator: Bool, checkSeparator: Bool) {
		var n = new Menu();
		for (label => channel in [
			"Move Up" => "line-move-up",
			"Move Down" => "line-move-down",
			"Insert" => "line-insert",
			"Delete" => "line-delete",
			"Duplicate" => "line-duplicate",
			"Show References" => "line-references-show",
		]) {
			var item = new MenuItem({ label : label });
			item.click = () -> {
				window.webContents.send(channel);
			};
			n.append(item);
		}

		var nsep = new MenuItem( { label : "Separator", role: "checkbox" } );
		nsep.enabled = enableSeparator;
		nsep.checked = checkSeparator;
		nsep.click = () -> window.webContents.send("line-separator");
		n.append(nsep);

		return n;
	}

	static function popupColumn(window: BrowserWindow, columnType: String, checked: Bool, ndispEnabled: Bool, niconEnabled: Bool) {
		var n = new Menu();
		for (label => channel in [
			"Edit" => "column-edit",
			"Add Column" => "column-add",
			"Move Left" => "column-move-left",
			"Move Right" => "column-move-right",
			"Delete" => "column-delete",
		]) {
			var item = new MenuItem({ label : label });
			item.click = () -> window.webContents.send(channel);
			n.append(item);
		}

		var ndisp = new MenuItem( { label : "Display Column", role : "checkbox" } );
		ndisp.click = () -> window.webContents.send("column-display");
		ndisp.checked = checked;
		ndisp.enabled = ndispEnabled;
		n.append(ndisp);

		var nicon = new MenuItem( { label : "Display Icon", role : "checkbox" } );
		nicon.click = () -> window.webContents.send("column-display-icon");
		nicon.checked = checked;
		nicon.enabled = niconEnabled;
		n.append(nicon);

		switch (columnType) {
			case "TId", "TString", "TEnum", "TFlags":
				var cm = new Menu();
				var conv = new MenuItem( { label : "Convert", submenu: cm } );
				for( k in ["lowercase", "UPPERCASE", "UpperIdent","lowerIdent"] ) {
					var m = new MenuItem( { label : k } );
					m.click = () -> window.webContents.send("column-convert-casing", k);
					cm.append(m);
				}
				n.append(conv);
			case "TInt", "TFloat":
				var cm = new Menu();
				var conv = new MenuItem( { label : "Convert", submenu: cm} );
				for (k in ["* 10", "/ 10", "+ 1", "-1"]) {
					var m = new MenuItem( { label : k } );
					m.click = () -> window.webContents.send("column-convert-number", k);
					cm.append(m);
				}
				n.append(conv);
			default:
		}

		return n;
	}

	static function popupSheet(window: BrowserWindow, showLevelCheckbox: Bool, nindexChecked: Bool, ngroupChecked: Bool, nlevelChecked: Bool) {
		var n = new Menu();
		for (label => channel in [
			"Add Sheet" => "sheet-add",
			"Move Left" => "sheet-move-left",
			"Move Right" => "sheet-move-right",
			"Rename" => "sheet-rename",
			"Delete" => "sheet-delete",
		]) {
			var item = new MenuItem({ label : label });
			item.click = () -> window.webContents.send(channel);
			n.append(item);
		}

		var nindex = new MenuItem( { label : "Add Index", role : "checkbox" } );
		nindex.click = () -> window.webContents.send("sheet-add-index");
		nindex.checked = nindexChecked;

		var ngroup = new MenuItem( { label : "Add Group", role : "checkbox" } );
		ngroup.click = () -> window.webContents.send("sheet-add-group");
		IpcMain.removeHandler("set-ngroup");
		ngroup.checked = nindexChecked;

		// CSV
		var csv = new Menu();
		var ncsv = new MenuItem( { label : "CSV...", submenu : csv} );
		
		var importSheetCSV = new MenuItem( { label : "Import Sheet Data...", role : "checkbox" } );
		importSheetCSV.click = () -> {
			Dialog.showOpenDialog({ properties: ['openFile'] }).then((response) -> {
				if (untyped response.filePaths[0] != null) {
					window.webContents.send("sheet-import-csv", sys.io.File.getContent(untyped response.filePaths[0]));
				}
			});
		};

		var exportSheetCSV = new MenuItem( { label : "Export Sheet Data...", role : "checkbox" } );
		exportSheetCSV.click = () -> window.webContents.send("sheet-export-csv");

		csv.append(importSheetCSV);
		csv.append(exportSheetCSV);

		// JSON
		var json = new Menu();
		var njson = new MenuItem( { label : "JSON...", submenu: json} );

		var importSheetJSON = new MenuItem( { label : "Import Sheet Data...", role : "checkbox" } );
		importSheetJSON.click = () -> {
			Dialog.showOpenDialog({ properties: ['openFile'] }).then((response) -> {
				if (untyped response.filePaths[0] != null) {
					window.webContents.send("sheet-import-json", sys.io.File.getContent(untyped response.filePaths[0]));
				}
			});
		};

		var exportSheetJSON = new MenuItem( { label : "Export Sheet Data...", role : "checkbox" } );
		exportSheetJSON.click = () -> window.webContents.send("sheet-export-json");

		json.append(importSheetJSON);
		json.append(exportSheetJSON);

		for( m in [nindex, ngroup, njson, ncsv] )
			n.append(m);
		
		if (showLevelCheckbox) {
			var nlevel = new MenuItem( { label : "Level", role : "checkbox" } );
			nlevel.checked = nlevelChecked;
			n.append(nlevel);
		}

		return n;
	}
}
