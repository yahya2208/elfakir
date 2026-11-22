$ErrorActionPreference = 'Stop'
$target = 'Supabase CLI:access-token'
$type = 1
$flag = 0
$CRED = @'
using System;
using System.Runtime.InteropServices;
public class NativeMethods {
    [StructLayout(LayoutKind.Sequential, CharSet = CharSet.Unicode)]
    public struct CREDENTIAL {
        public int Type;
        public int Flags;
        [MarshalAs(UnmanagedType.LPWStr)]
        public string TargetName;
        [MarshalAs(UnmanagedType.LPWStr)]
        public string Comment;
        public long LastWritten;
        public int CredentialBlobSize;
        public IntPtr CredentialBlob;
        public int Persist;
        [MarshalAs(UnmanagedType.LPWStr)]
        public string UserName;
        [MarshalAs(UnmanagedType.LPWStr)]
        public string CredentialBlobString;
    }

    [DllImport("advapi32.dll", EntryPoint = "CredReadW", CharSet = CharSet.Unicode, SetLastError = true)]
    public static extern bool CredRead(string target, int type, int flag, out IntPtr Credential);

    [DllImport("advapi32.dll")]
    public static extern void CredFree(IntPtr cred);
}
'@
Add-Type $CRED
$credPtr = [IntPtr]::Zero
$readResult = [NativeMethods]::CredRead($target, $type, $flag, [ref]$credPtr)
if (!$readResult) { Write-Output "" ; exit 1 }
$structure = [System.Runtime.InteropServices.Marshal]::PtrToStructure($credPtr, [type][NativeMethods+CREDENTIAL])
$credentialBytes = New-Object Byte[] $structure.CredentialBlobSize
[System.Runtime.InteropServices.Marshal]::Copy($structure.CredentialBlob, $credentialBytes, 0, $structure.CredentialBlobSize)
[System.Text.Encoding]::UTF8.GetString($credentialBytes)
[NativeMethods]::CredFree($credPtr)
