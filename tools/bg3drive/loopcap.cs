// loopcap.exe OUT.raw [TRIGGER]: WASAPI loopback capture of the default playback device -> raw s16le 48 kHz stereo file.
// With TRIGGER it waits until that file exists (rec.sh creates it when the video has started), so audio and video begin together.
// Fills silent stretches with zeros (loopback delivers no packets while nothing plays) so the stream stays
// continuous in wall-clock time. Needs no install and changes no Windows sound setting.
// Build: C:\Windows\Microsoft.NET\Framework64\v4.0.30319\csc.exe /nologo /out:loopcap.exe loopcap.cs
using System;
using System.Diagnostics;
using System.IO;
using System.Runtime.InteropServices;
using System.Threading;

static class P {
  [ComImport, Guid("BCDE0395-E52F-467C-8E3D-C4579291692E")] class MMDeviceEnumerator { }
  [ComImport, Guid("A95664D2-9614-4F35-A746-DE8DB63617E6"), InterfaceType(ComInterfaceType.InterfaceIsIUnknown)]
  interface IMMDeviceEnumerator {
    int EnumAudioEndpoints(int flow, int mask, out IntPtr devs);
    int GetDefaultAudioEndpoint(int flow, int role, out IMMDevice dev);
  }
  [ComImport, Guid("D666063F-1587-4E43-81F1-B948E807363F"), InterfaceType(ComInterfaceType.InterfaceIsIUnknown)]
  interface IMMDevice {
    int Activate(ref Guid iid, int ctx, IntPtr p, [MarshalAs(UnmanagedType.IUnknown)] out object o);
  }
  [ComImport, Guid("1CB9AD4C-DBFA-4C32-B178-C2F568A703B2"), InterfaceType(ComInterfaceType.InterfaceIsIUnknown)]
  interface IAudioClient {
    int Initialize(int mode, int flags, long bufDur, long period, IntPtr fmt, IntPtr session);
    int GetBufferSize(out uint n);
    int GetStreamLatency(out long l);
    int GetCurrentPadding(out uint n);
    int IsFormatSupported(int mode, IntPtr fmt, out IntPtr closest);
    int GetMixFormat(out IntPtr fmt);
    int GetDevicePeriod(out long def, out long min);
    int Start();
    int Stop();
    int Reset();
    int SetEventHandle(IntPtr h);
    int GetService(ref Guid iid, [MarshalAs(UnmanagedType.IUnknown)] out object o);
  }
  [ComImport, Guid("C8ADBD64-E71E-48A0-A4DE-185C395CD317"), InterfaceType(ComInterfaceType.InterfaceIsIUnknown)]
  interface IAudioCaptureClient {
    int GetBuffer(out IntPtr data, out uint frames, out uint flags, out long pos, out long qpc);
    int ReleaseBuffer(uint frames);
    int GetNextPacketSize(out uint frames);
  }

  static int Main(string[] a) {
    if (a.Length < 1) { Console.Error.WriteLine("usage: loopcap OUT.raw [TRIGGER]"); return 1; }
    var enumr = (IMMDeviceEnumerator)new MMDeviceEnumerator();
    IMMDevice dev; Check(enumr.GetDefaultAudioEndpoint(0, 0, out dev), "default endpoint");   // eRender, eConsole
    Guid iidClient = new Guid("1CB9AD4C-DBFA-4C32-B178-C2F568A703B2");
    object o; Check(dev.Activate(ref iidClient, 23, IntPtr.Zero, out o), "activate");
    var client = (IAudioClient)o;
    // WAVEFORMATEX: PCM 16-bit stereo 48 kHz; AUTOCONVERTPCM lets the engine convert from the device mix format.
    IntPtr fmt = Marshal.AllocHGlobal(18);
    Marshal.WriteInt16(fmt, 0, 1); Marshal.WriteInt16(fmt, 2, 2); Marshal.WriteInt32(fmt, 4, 48000);
    Marshal.WriteInt32(fmt, 8, 48000 * 4); Marshal.WriteInt16(fmt, 12, 4); Marshal.WriteInt16(fmt, 14, 16); Marshal.WriteInt16(fmt, 16, 0);
    const int LOOPBACK = 0x20000, SRCQ = 0x08000000;
    Check(client.Initialize(0, LOOPBACK | unchecked((int)0x80000000) | SRCQ, 10000000, 0, fmt, IntPtr.Zero), "initialize");
    Guid iidCap = new Guid("C8ADBD64-E71E-48A0-A4DE-185C395CD317");
    Check(client.GetService(ref iidCap, out o), "capture service");
    var cap = (IAudioCaptureClient)o;
    var stdout = new FileStream(a[0], FileMode.Create, FileAccess.Write, FileShare.Read);
    if (a.Length > 1) while (!File.Exists(a[1])) Thread.Sleep(5);
    client.Start();
    var sw = Stopwatch.StartNew();   // t0 = capture start
    long written = 0; byte[] buf = new byte[1 << 16];
    while (true) {
      uint n; Check(cap.GetNextPacketSize(out n), "packet size");
      while (n > 0) {
        IntPtr data; uint frames, flags; long pos, qpc;
        Check(cap.GetBuffer(out data, out frames, out flags, out pos, out qpc), "get buffer");
        int bytes = (int)frames * 4;
        if (buf.Length < bytes) buf = new byte[bytes];
        if ((flags & 2) != 0) Array.Clear(buf, 0, bytes); else Marshal.Copy(data, buf, 0, bytes);   // AUDCLNT_BUFFERFLAGS_SILENT
        stdout.Write(buf, 0, bytes); written += frames;
        cap.ReleaseBuffer(frames);
        Check(cap.GetNextPacketSize(out n), "packet size");
      }
      long expected = sw.ElapsedMilliseconds * 48;           // frames that should exist by now
      long gap = expected - written;
      if (gap > 2400) {                                      // > 50 ms with no packets: pad silence
        int g = (int)Math.Min(gap, 48000);
        stdout.Write(new byte[g * 4], 0, g * 4); written += g;
      }
      stdout.Flush();
      Thread.Sleep(10);
    }
  }
  static void Check(int hr, string what) {
    if (hr < 0) { Console.Error.WriteLine("loopcap: " + what + " failed 0x" + hr.ToString("X8")); Environment.Exit(2); }
  }
}
