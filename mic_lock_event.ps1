<#
.SYNOPSIS
    MicLock Event: Event-driven Windows microphone volume lock using native WASAPI callbacks.
.DESCRIPTION
    Unlike traditional polling scripts, MicLock Event registers a native Windows CoreAudio
    IAudioEndpointVolumeCallback. It reacts in real-time (< 1ms) whenever any process (Discord,
    Zoom, Steam, WebRTC) attempts to alter the recording volume, reverting it with 0% idle CPU.
.PARAMETER TargetVolume
    Target volume percentage (0 - 100). Default is 100.
.PARAMETER LogFile
    Optional custom path to log file. Defaults to mic_lock.log in script directory.
#>
param(
    [ValidateRange(0, 100)]
    [int]$TargetVolume = 100,

    [string]$LogFile = "$PSScriptRoot\mic_lock.log"
)

# CoreAudio WASAPI COM interop type definition
$csharpCode = @'
using System;
using System.Runtime.InteropServices;

namespace MicLockNative
{
    public enum EDataFlow { eRender, eCapture, eAll }
    public enum ERole { eConsole, eMultimedia, eCommunications }

    [StructLayout(LayoutKind.Sequential)]
    public struct AUDIO_VOLUME_NOTIFICATION_DATA
    {
        public Guid guidEventContext;
        public bool bMuted;
        public float fMasterVolume;
        public uint nChannels;
        public float afChannelVolumes;
    }

    [Guid("6578E56E-F622-4414-8A8F-44F4A1AEB744"), InterfaceType(ComInterfaceType.InterfaceIsIUnknown)]
    public interface IAudioEndpointVolumeCallback
    {
        [PreserveSig] int OnNotify(IntPtr pNotify);
    }

    [Guid("5CDF2C82-841E-4546-9722-0CF74078229A"), InterfaceType(ComInterfaceType.InterfaceIsIUnknown)]
    public interface IAudioEndpointVolume
    {
        [PreserveSig] int RegisterControlChangeNotify(IAudioEndpointVolumeCallback pNotify);
        [PreserveSig] int UnregisterControlChangeNotify(IAudioEndpointVolumeCallback pNotify);
        [PreserveSig] int GetChannelCount(out uint pnChannelCount);
        [PreserveSig] int SetMasterVolumeLevel(float fLevelDB, ref Guid pguidEventContext);
        [PreserveSig] int SetMasterVolumeLevelScalar(float fLevel, ref Guid pguidEventContext);
        [PreserveSig] int GetMasterVolumeLevel(out float pfLevelDB);
        [PreserveSig] int GetMasterVolumeLevelScalar(out float pfLevel);
        [PreserveSig] int SetChannelVolumeLevel(uint nChannel, float fLevelDB, ref Guid pguidEventContext);
        [PreserveSig] int SetChannelVolumeLevelScalar(uint nChannel, float fLevel, ref Guid pguidEventContext);
        [PreserveSig] int GetChannelVolumeLevel(uint nChannel, out float pfLevelDB);
        [PreserveSig] int GetChannelVolumeLevelScalar(uint nChannel, out float pfLevel);
        [PreserveSig] int SetMute([MarshalAs(UnmanagedType.Bool)] bool bMute, ref Guid pguidEventContext);
        [PreserveSig] int GetMute(out bool pbMute);
        [PreserveSig] int GetVolumeStepInfo(out uint pnStep, out uint pnStepCount);
        [PreserveSig] int VolumeStepUp(ref Guid pguidEventContext);
        [PreserveSig] int VolumeStepDown(ref Guid pguidEventContext);
        [PreserveSig] int QueryHardwareSupport(out uint pdwHardwareSupportMask);
        [PreserveSig] int GetVolumeRange(out float pflVolumeMindB, out float pflVolumeMaxdB, out float pflVolumeIncrementdB);
    }

    [Guid("D666063F-1587-4E43-81F1-B948E807363F"), InterfaceType(ComInterfaceType.InterfaceIsIUnknown)]
    public interface IMMDevice
    {
        [PreserveSig] int Activate(ref Guid iid, uint dwClsCtx, IntPtr pActivationParams, [MarshalAs(UnmanagedType.IUnknown)] out object ppInterface);
        [PreserveSig] int OpenPropertyStore(uint stgmAccess, out IntPtr ppProperties);
        [PreserveSig] int GetId([MarshalAs(UnmanagedType.LPWStr)] out string ppstrId);
        [PreserveSig] int GetState(out uint pdwState);
    }

    [Guid("A95664D2-9614-4F35-A746-DE8DB63617E6"), InterfaceType(ComInterfaceType.InterfaceIsIUnknown)]
    public interface IMMDeviceEnumerator
    {
        [PreserveSig] int EnumAudioEndpoints(EDataFlow dataFlow, uint dwStateMask, out IntPtr ppDevices);
        [PreserveSig] int GetDefaultAudioEndpoint(EDataFlow dataFlow, ERole role, out IMMDevice ppEndpoint);
    }

    [ComImport, Guid("BCDE0395-E52F-467C-8E3D-C4579291692E")]
    public class MMDeviceEnumeratorComObject { }

    public class EventLockWatcher : IAudioEndpointVolumeCallback, IDisposable
    {
        private IAudioEndpointVolume _endpoint;
        private float _targetVolume = 1.0f;
        private bool _isReverting = false;
        private Guid _context = Guid.NewGuid();

        public event Action<int, int> OnVolumeReverted;

        public float TargetVolume
        {
            get { return _targetVolume; }
            set
            {
                if (value < 0f) _targetVolume = 0f;
                else if (value > 1f) _targetVolume = 1f;
                else _targetVolume = value;
                Enforce();
            }
        }

        public int Start(float targetScalar)
        {
            if (targetScalar < 0f) _targetVolume = 0f;
            else if (targetScalar > 1f) _targetVolume = 1f;
            else _targetVolume = targetScalar;

            var enumerator = (IMMDeviceEnumerator)(new MMDeviceEnumeratorComObject());
            IMMDevice dev;
            int hr = enumerator.GetDefaultAudioEndpoint(EDataFlow.eCapture, ERole.eConsole, out dev);
            if (hr != 0 || dev == null) return hr;

            Guid iid = typeof(IAudioEndpointVolume).GUID;
            object obj;
            hr = dev.Activate(ref iid, 1 /* CLSCTX_INPROC_SERVER */, IntPtr.Zero, out obj);
            if (hr != 0 || obj == null) return hr;

            _endpoint = (IAudioEndpointVolume)obj;
            _endpoint.RegisterControlChangeNotify(this);

            Enforce();
            return 0;
        }

        public int OnNotify(IntPtr pNotify)
        {
            if (_isReverting || _endpoint == null) return 0;
            try
            {
                var data = (AUDIO_VOLUME_NOTIFICATION_DATA)Marshal.PtrToStructure(pNotify, typeof(AUDIO_VOLUME_NOTIFICATION_DATA));
                int currentPercent = (int)Math.Round(data.fMasterVolume * 100f);
                int targetPercent = (int)Math.Round(_targetVolume * 100f);

                if (Math.Abs(data.fMasterVolume - _targetVolume) > 0.01f)
                {
                    _isReverting = true;
                    _endpoint.SetMasterVolumeLevelScalar(_targetVolume, ref _context);
                    _isReverting = false;

                    var handler = OnVolumeReverted;
                    if (handler != null)
                    {
                        handler(currentPercent, targetPercent);
                    }
                }
            }
            catch {}
            return 0;
        }

        private void Enforce()
        {
            if (_endpoint != null)
            {
                _isReverting = true;
                try { _endpoint.SetMasterVolumeLevelScalar(_targetVolume, ref _context); }
                catch {}
                finally { _isReverting = false; }
            }
        }

        public void Dispose()
        {
            if (_endpoint != null)
            {
                try { _endpoint.UnregisterControlChangeNotify(this); } catch {}
                Marshal.ReleaseComObject(_endpoint);
                _endpoint = null;
            }
        }
    }
}
'@

if (-not ([System.Management.Automation.PSTypeName]'MicLockNative.EventLockWatcher').Type) {
    Add-Type -TypeDefinition $csharpCode -Language CSharp
}

function Log-Message([string]$msg) {
    $timestamp = (Get-Date).ToString("yyyy-MM-dd HH:mm:ss")
    $line = "[$timestamp] $msg"
    Write-Host $line
    try {
        $line | Out-File -FilePath $LogFile -Append -Encoding utf8
    } catch {}
}

$watcher = New-Object MicLockNative.EventLockWatcher

# Register event callback
$action = {
    param([int]$prev, [int]$restored)
    Log-Message "External change prevented: $prev% -> Reverted to $restored%"
}
$watcher.add_OnVolumeReverted($action)

$targetScalar = [float]($TargetVolume / 100.0)
$initResult = $watcher.Start($targetScalar)

if ($initResult -ne 0) {
    Log-Message "Error initializing WASAPI endpoint listener (HRESULT: 0x$($initResult.ToString('X8')))"
    exit 1
}

Log-Message "MicLock Event started (Target: $TargetVolume%, Zero-Polling Active)"

try {
    # Keep script alive without busy loop or polling (0.00% CPU)
    [System.Threading.Thread]::Sleep([System.Threading.Timeout]::Infinite)
} finally {
    $watcher.Dispose()
    Log-Message "MicLock Event stopped."
}
