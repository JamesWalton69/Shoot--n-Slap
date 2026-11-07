import os
import numpy as np
from PIL import Image

OUT_DIR = os.path.dirname(os.path.abspath(__file__))
SIZE = 1024

def make_seamless_noise(size, scale, seed=42):
    np.random.seed(seed)
    grid_size = max(2, int(size // scale))
    grid = np.random.rand(grid_size, grid_size).astype(np.float32)
    x = np.linspace(0, grid_size, size, endpoint=False)
    y = np.linspace(0, grid_size, size, endpoint=False)
    xi, yi = x.astype(int) % grid_size, y.astype(int) % grid_size
    xf, yf = x - x.astype(int), y - y.astype(int)
    xf = xf * xf * (3 - 2 * xf)
    yf = yf * yf * (3 - 2 * yf)
    g00 = grid[np.ix_(yi, xi)]
    g10 = grid[np.ix_(yi, (xi + 1) % grid_size)]
    g01 = grid[np.ix_((yi + 1) % grid_size, xi)]
    g11 = grid[np.ix_((yi + 1) % grid_size, (xi + 1) % grid_size)]
    col0 = g00 * (1 - yf[:, None]) + g01 * yf[:, None]
    col1 = g10 * (1 - yf[:, None]) + g11 * yf[:, None]
    return col0 * (1 - xf[None, :]) + col1 * xf[None, :]

def fbm(size, octaves=5, lacunarity=2.0, gain=0.5, base_scale=256, seed=123):
    total = np.zeros((size, size), dtype=np.float32)
    amp = 1.0
    scale = base_scale
    for i in range(octaves):
        n = make_seamless_noise(size, scale, seed=seed + i * 97)
        total += n * amp
        amp *= gain
        scale /= lacunarity
    return (total - total.min()) / (total.max() - total.min() + 1e-6)

print("Generating Rooftop Tar & Gravel PBR Textures...")
gravel_fine = fbm(SIZE, octaves=6, base_scale=32, seed=777)
gravel_coarse = fbm(SIZE, octaves=4, base_scale=128, seed=888)
tar_seams_x = np.abs(np.sin(np.linspace(0, 4 * np.pi, SIZE)))[:, None]
tar_seam_line = (tar_seams_x < 0.05).astype(np.float32)

# Large water puddle noise
puddle_noise = fbm(SIZE, octaves=3, base_scale=320, seed=555)
puddle_mask = (puddle_noise > 0.60).astype(np.float32)
puddle_smooth = (puddle_noise - 0.60).clip(0, 1) / 0.40
puddle_smooth = np.clip(puddle_smooth * 2.5, 0.0, 1.0)

# Colors: dark asphalt gravel with water pools
tar_black = np.array([0.07, 0.07, 0.08], dtype=np.float32)
gravel_grey = np.array([0.16, 0.17, 0.19], dtype=np.float32)
water_reflect = np.array([0.03, 0.04, 0.05], dtype=np.float32)

albedo = gravel_grey[None, None, :] * (0.8 + 0.35 * gravel_fine[:, :, None]) + tar_black[None, None, :] * (0.2 + 0.3 * gravel_coarse[:, :, None])
# Darken tar seams
albedo = albedo * (1.0 - tar_seam_line[:, :, None] * 0.45)
# Water puddles (glassy dark wetness)
albedo = albedo * (1.0 - puddle_smooth[:, :, None] * 0.8) + water_reflect[None, None, :] * (puddle_smooth[:, :, None] * 0.8)

Image.fromarray((albedo * 255).clip(0, 255).astype(np.uint8)).save(os.path.join(OUT_DIR, "rooftop_gravel_albedo.png"))
print("Saved rooftop_gravel_albedo.png")

# Normal map
height = gravel_fine * 0.45 + gravel_coarse * 0.35 - tar_seam_line * 0.2 - puddle_smooth * 0.5
hx = np.roll(height, -1, axis=1) - np.roll(height, 1, axis=1)
hy = np.roll(height, -1, axis=0) - np.roll(height, 1, axis=0)
nx, ny, nz = -hx * 5.0, -hy * 5.0, np.ones_like(height)
norm = np.sqrt(nx**2 + ny**2 + nz**2)
nx, ny, nz = nx/norm, ny/norm, nz/norm
# Puddles flatten the normal completely to flat mirror (0, 0, 1)
nx = nx * (1.0 - puddle_smooth)
ny = ny * (1.0 - puddle_smooth)
nz = nz * (1.0 - puddle_smooth) + puddle_smooth

r = ((nx * 0.5 + 0.5) * 255).clip(0, 255).astype(np.uint8)
g = ((ny * 0.5 + 0.5) * 255).clip(0, 255).astype(np.uint8)
b = ((nz * 0.5 + 0.5) * 255).clip(0, 255).astype(np.uint8)
Image.fromarray(np.stack([r, g, b], axis=-1)).save(os.path.join(OUT_DIR, "rooftop_gravel_normal.png"))
print("Saved rooftop_gravel_normal.png")

# Roughness: dry gravel is rough (0.92), standing water puddles are ultra-smooth mirror (0.02)!
roughness = (0.90 + 0.08 * gravel_coarse) * (1.0 - puddle_smooth) + 0.02 * puddle_smooth
Image.fromarray((roughness * 255).clip(0, 255).astype(np.uint8)).save(os.path.join(OUT_DIR, "rooftop_gravel_roughness.png"))
print("Saved rooftop_gravel_roughness.png")

print("Rooftop PBR textures complete!")
