# Rewrites the icon resources of the exported exe from icon.ico.
# Godot 4.7.2's exporter replaces the icons itself but writes the icon group's name ("GODOT_ICON")
# with a broken offset, so at runtime LoadIcon(GODOT_ICON) fails, the window class falls back to
# the generic Windows icon and the taskbar shows that. Explorer still finds the first group,
# which is why the file and shortcut looked right. This keeps the version info and manifest,
# writes every image of icon.ico as RT_ICON and a group named GODOT_ICON pointing at them.
# Only safe because the pck is not embedded (UpdateResource drops data appended to the exe).
param(
	[string]$Exe = (Join-Path (Split-Path $PSScriptRoot -Parent) "build/Soizwoed.exe"),
	[string]$Icon = (Join-Path (Split-Path $PSScriptRoot -Parent) "icon.ico")
)
$ErrorActionPreference = "Stop"

Add-Type @"
using System;
using System.Collections.Generic;
using System.IO;
using System.Runtime.InteropServices;

public static class ExeIcon {
	const uint LOAD_AS_DATAFILE = 0x2;
	const ushort LANG = 1033;
	const int RT_ICON = 3, RT_GROUP_ICON = 14, RT_VERSION = 16, RT_MANIFEST = 24;

	[DllImport("kernel32.dll", CharSet = CharSet.Unicode, SetLastError = true)] static extern IntPtr LoadLibraryEx(string f, IntPtr h, uint flags);
	[DllImport("kernel32.dll")] static extern bool FreeLibrary(IntPtr m);
	[DllImport("kernel32.dll")] static extern IntPtr FindResource(IntPtr m, IntPtr name, IntPtr type);
	[DllImport("kernel32.dll")] static extern IntPtr LoadResource(IntPtr m, IntPtr res);
	[DllImport("kernel32.dll")] static extern IntPtr LockResource(IntPtr data);
	[DllImport("kernel32.dll")] static extern uint SizeofResource(IntPtr m, IntPtr res);
	[DllImport("kernel32.dll", CharSet = CharSet.Unicode, SetLastError = true)] static extern IntPtr BeginUpdateResource(string f, bool deleteExisting);
	[DllImport("kernel32.dll", SetLastError = true)] static extern bool UpdateResource(IntPtr u, IntPtr type, IntPtr name, ushort lang, byte[] data, uint size);
	[DllImport("kernel32.dll", CharSet = CharSet.Unicode, SetLastError = true)] static extern bool UpdateResource(IntPtr u, IntPtr type, string name, ushort lang, byte[] data, uint size);
	[DllImport("kernel32.dll", SetLastError = true)] static extern bool EndUpdateResource(IntPtr u, bool discard);
	[DllImport("user32.dll", CharSet = CharSet.Unicode)] static extern IntPtr LoadIcon(IntPtr m, string name);

	static byte[] Read(IntPtr m, int type, int id) {
		IntPtr res = FindResource(m, (IntPtr)id, (IntPtr)type);
		if (res == IntPtr.Zero) return null;
		uint size = SizeofResource(m, res);
		byte[] bytes = new byte[size];
		Marshal.Copy(LockResource(LoadResource(m, res)), bytes, 0, (int)size);
		return bytes;
	}

	static void Check(bool ok, string what) {
		if (!ok) throw new Exception(what + " failed, Win32 error " + Marshal.GetLastWin32Error());
	}

	public static int Fix(string exe, string ico) {
		IntPtr m = LoadLibraryEx(exe, IntPtr.Zero, LOAD_AS_DATAFILE);
		Check(m != IntPtr.Zero, "LoadLibraryEx");
		byte[] version = Read(m, RT_VERSION, 1);
		byte[] manifest = Read(m, RT_MANIFEST, 1);
		FreeLibrary(m);

		byte[] file = File.ReadAllBytes(ico);
		int count = BitConverter.ToUInt16(file, 4);
		var group = new MemoryStream();
		var w = new BinaryWriter(group);
		w.Write((ushort)0); w.Write((ushort)1); w.Write((ushort)count);
		var images = new List<byte[]>();
		for (int i = 0; i < count; i++) {
			int e = 6 + 16 * i;
			int size = BitConverter.ToInt32(file, e + 8);
			int offset = BitConverter.ToInt32(file, e + 12);
			byte[] image = new byte[size];
			Array.Copy(file, offset, image, 0, size);
			images.Add(image);
			w.Write(file, e, 12);  // width, height, colours, reserved, planes, bit count, bytes in res
			w.Write((ushort)(i + 1));
		}

		IntPtr u = BeginUpdateResource(exe, true);
		Check(u != IntPtr.Zero, "BeginUpdateResource");
		for (int i = 0; i < count; i++)
			Check(UpdateResource(u, (IntPtr)RT_ICON, (IntPtr)(i + 1), LANG, images[i], (uint)images[i].Length), "UpdateResource icon");
		byte[] dir = group.ToArray();
		Check(UpdateResource(u, (IntPtr)RT_GROUP_ICON, "GODOT_ICON", LANG, dir, (uint)dir.Length), "UpdateResource group");
		if (version != null) Check(UpdateResource(u, (IntPtr)RT_VERSION, (IntPtr)1, LANG, version, (uint)version.Length), "UpdateResource version");
		if (manifest != null) Check(UpdateResource(u, (IntPtr)RT_MANIFEST, (IntPtr)1, LANG, manifest, (uint)manifest.Length), "UpdateResource manifest");
		Check(EndUpdateResource(u, false), "EndUpdateResource");

		// What the game does at startup for its window class.
		m = LoadLibraryEx(exe, IntPtr.Zero, LOAD_AS_DATAFILE);
		bool found = LoadIcon(m, "GODOT_ICON") != IntPtr.Zero;
		FreeLibrary(m);
		if (!found) throw new Exception("GODOT_ICON still not loadable");
		return count;
	}
}
"@

if (-not (Test-Path $Exe)) { Write-Host "ICON FIX FAILED: $Exe not found" -ForegroundColor Red; exit 1 }
try {
	$count = [ExeIcon]::Fix((Resolve-Path $Exe).Path, (Resolve-Path $Icon).Path)
	Write-Host "ICON FIX OK: $count images, group GODOT_ICON"
} catch {
	Write-Host "ICON FIX FAILED: $($_.Exception.Message)" -ForegroundColor Red
	exit 1
}
