# Graphics Programming assignment
## 🌘 SSAO Shader – Unity 6 (URP)
---
This project implements a Screen Space Ambient Occlusion (SSAO) effect for Unity 6 with Universal Render Pipeline (URP), using a Custom Render Pass.

The goal is to provide a flexible ambient occlusion system, 
configurable directly from the Inspector, supporting both spherical and hemispherical sampling, with multiple occlusion functions inspired by OpenGL tutorials and GPU Gems articles.
### Usage
---
1. Go to Assets>Settings.
2. Enable the **Custom SSAO Renderer Feature** in your URP Asset (PC_Renderer).
3. Experiment with different sampling methods, occlusion functions and other parameters, such as sampling radius, kernel size, bias and thresholds.

### Compatibility
---
- Tested on a device running **Direct3D (DirectX 11)**. 
- Should also work with **OpenGL**, but not explicitly tested.

### Results
---
<p><strong>Spherical Method, Occlusion function V3</strong> (with dark areas enhanced)</p>
<img src="Docs/SSAO_V3_Spherical.png" width="800"/>

---
<p><strong>Hemispherical Method, Occlusion function V2</strong></p>
<img src="Docs/SSAO_V2_Hemispherical.png" width="800"/>

---
<p><strong>Hemispherical Method, Occlusion function V3</strong></p>
<img src="Docs/SSAO_V3_Hemispherical.png" width="800"/>

## 🎨 Hatching Shaders
---
In addition to SSAO, the project also includes **hatching shaders** inspired by engraving and etching techniques (major inspiration is from Gustave Doré drawings).  
These shaders simulate hand-drawn crosshatching by combining procedural bands, noise, Voronoi textures, and paper overlays.
### Results
---
<p><strong>Hatching WS</strong></p>
<img src="Docs/Hatching3D_1.png" width="800"/>

---
<p><strong>Hatching CS</strong></p>
<img src="Docs/Hatching3D_2.png" width="800"/>

---
<p><strong>Hatching CS - multiple lights</strong></p>
<img src="Docs/Hatching3D_2_1.png" width="800"/>

