// d3d12probe: reports what the Wine/D3DMetal stack exposes to a D3D12 game.
// Build: x86_64-w64-mingw32-gcc -O2 -o d3d12probe.exe d3d12probe.c -ld3d12 -ldxgi -luuid
#define COBJMACROS
#define INITGUID
#include <windows.h>
#include <stdio.h>
#include <dxgi1_6.h>
#include <d3d12.h>

static void print_module(const char *name)
{
    char path[MAX_PATH] = "(not loaded)";
    HMODULE m = GetModuleHandleA(name);
    if (m) GetModuleFileNameA(m, path, sizeof(path));
    printf("module %-10s %s\n", name, path);
}

int main(void)
{
    IDXGIFactory4 *factory = NULL;
    HRESULT hr = CreateDXGIFactory1(&IID_IDXGIFactory4, (void **)&factory);
    printf("CreateDXGIFactory1: 0x%08lx\n", hr);
    if (FAILED(hr)) return 1;

    IDXGIAdapter1 *adapter = NULL;
    if (SUCCEEDED(IDXGIFactory4_EnumAdapters1(factory, 0, &adapter))) {
        DXGI_ADAPTER_DESC1 desc;
        IDXGIAdapter1_GetDesc1(adapter, &desc);
        printf("adapter0: %ls  vendor=0x%04x device=0x%04x vram=%llu MB\n", desc.Description,
               desc.VendorId, desc.DeviceId, (unsigned long long)desc.DedicatedVideoMemory >> 20);
    }

    ID3D12Device *device = NULL;
    hr = D3D12CreateDevice((IUnknown *)adapter, D3D_FEATURE_LEVEL_12_0, &IID_ID3D12Device, (void **)&device);
    printf("D3D12CreateDevice(FL 12_0): 0x%08lx\n", hr);
    print_module("d3d12.dll");
    print_module("dxgi.dll");
    if (FAILED(hr)) return 2;

    D3D_FEATURE_LEVEL levels[] = {D3D_FEATURE_LEVEL_12_2, D3D_FEATURE_LEVEL_12_1, D3D_FEATURE_LEVEL_12_0};
    D3D12_FEATURE_DATA_FEATURE_LEVELS fl = {3, levels, 0};
    if (SUCCEEDED(ID3D12Device_CheckFeatureSupport(device, D3D12_FEATURE_FEATURE_LEVELS, &fl, sizeof(fl))))
        printf("max feature level: 0x%x\n", fl.MaxSupportedFeatureLevel);

    // Ask for the highest model and step down until the runtime accepts it.
    for (int sm = 0x69; sm >= 0x60; sm--) {
        D3D12_FEATURE_DATA_SHADER_MODEL m = {(D3D_SHADER_MODEL)sm};
        if (SUCCEEDED(ID3D12Device_CheckFeatureSupport(device, D3D12_FEATURE_SHADER_MODEL, &m, sizeof(m)))) {
            printf("highest shader model: %d.%d\n", m.HighestShaderModel >> 4, m.HighestShaderModel & 0xf);
            break;
        }
    }

    D3D12_FEATURE_DATA_D3D12_OPTIONS o = {0};
    if (SUCCEEDED(ID3D12Device_CheckFeatureSupport(device, D3D12_FEATURE_D3D12_OPTIONS, &o, sizeof(o))))
        printf("resource binding tier: %d  tiled resources tier: %d  typed UAV load ext: %d\n",
               o.ResourceBindingTier, o.TiledResourcesTier, o.TypedUAVLoadAdditionalFormats);

    D3D12_FEATURE_DATA_D3D12_OPTIONS1 o1 = {0};
    if (SUCCEEDED(ID3D12Device_CheckFeatureSupport(device, D3D12_FEATURE_D3D12_OPTIONS1, &o1, sizeof(o1))))
        printf("wave ops: %d  wave lanes: %u-%u  int64: %d\n", o1.WaveOps, o1.WaveLaneCountMin,
               o1.WaveLaneCountMax, o1.Int64ShaderOps);

    D3D12_FEATURE_DATA_D3D12_OPTIONS5 o5 = {0};
    if (SUCCEEDED(ID3D12Device_CheckFeatureSupport(device, D3D12_FEATURE_D3D12_OPTIONS5, &o5, sizeof(o5))))
        printf("raytracing tier: %d\n", o5.RaytracingTier);

    D3D12_FEATURE_DATA_D3D12_OPTIONS7 o7 = {0};
    if (SUCCEEDED(ID3D12Device_CheckFeatureSupport(device, D3D12_FEATURE_D3D12_OPTIONS7, &o7, sizeof(o7))))
        printf("mesh shader tier: %d  sampler feedback tier: %d\n", o7.MeshShaderTier, o7.SamplerFeedbackTier);

    printf("probe ok\n");
    return 0;
}
