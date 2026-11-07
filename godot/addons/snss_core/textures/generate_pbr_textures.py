import os
import numpy as np
from PIL import Image

OUT_DIR = r"E:\Coding\Projects\Shoot-'n-Slap\godot\addons\snss_core\textures"
os.makedirs(OUT_DIR, exist_ok=True)
SIZE = 1024

def make_seamless_noise(size, scale, seed=42):
    np.random.seed(seed)
    grid_size = max(2, int(size // scale))
    grid = np.random.rand(grid_size, grid_size).astype(np.float32)
    # Tile grid
    tiled = np.pad(grid, ((0, 1), (0, 1)), mode='wrap')
    # Bilinear interpolation for smooth continuous noise
    # Let's do vectorized bicubic or bilinear interpolation
    y = np.linspace(0, grid_size, size, endpoint=False)
    x = np.linspace(0, grid_size, size, endpoint=False)
    xi = x.astype(int) % grid_size
    yi = y.astype(int) % grid_size
    xf = x - x.astype(int)
    yf = y - y.astype(int)
    # Smoothstep
    xf = xf * xf * (3 - 2 * xf)
    yf = yf * yf * (3 - 2 * yf)
    
    xip1 = (xi + 1) % grid_size
    yip1 = (yi + 1) % grid_size
    
    g00 = grid[np.ix_(yi, xi)]
    g10 = grid[np.ix_(yi, xip1)]
    g01 = grid[np.ix_(yip1, xi)]
    g11 = grid[np.ix_(yip1, xip1)]
    
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
    total = (total - total.min()) / (total.max() - total.min() + 1e-6)
    return total

def height_to_normal(height, strength=3.0):
    # Sobel filter with wrap around
    hx = np.roll(height, -1, axis=1) - np.roll(height, 1, axis=1)
    hy = np.roll(height, -1, axis=0) - np.roll(height, 1, axis=0)
    
    # In Godot 4 OpenGL normal maps: X is right (red), Y is up (green), Z is out (blue)
    # hx gradient pointing right means normal tilts left, so -hx
    # hy gradient pointing down means normal tilts up, so -hy
    nx = -hx * strength
    ny = -hy * strength
    nz = np.ones_like(height)
    
    norm = np.sqrt(nx**2 + ny**2 + nz**2)
    nx /= norm
    ny /= norm
    nz /= norm
    
    r = ((nx * 0.5 + 0.5) * 255).clip(0, 255).astype(np.uint8)
    g = ((ny * 0.5 + 0.5) * 255).clip(0, 255).astype(np.uint8)
    b = ((nz * 0.5 + 0.5) * 255).clip(0, 255).astype(np.uint8)
    return np.stack([r, g, b], axis=-1)

def save_image(arr, name):
    path = os.path.join(OUT_DIR, name)
    if arr.ndim == 2:
        img = Image.fromarray((arr * 255).clip(0, 255).astype(np.uint8), mode='L')
    else:
        img = Image.fromarray(arr.astype(np.uint8), mode='RGB')
    img.save(path)
    print(f"Saved: {name}")

print("Generating PBR Textures...")

# ----------------------------------------------------
# 1. CONCRETE FLOOR (Stains, fine aggregate, dark oil spots)
# ----------------------------------------------------
print("1. Concrete Floor...")
base_grain = fbm(SIZE, octaves=6, base_scale=64, seed=10)
large_stains = fbm(SIZE, octaves=4, base_scale=380, seed=25)
puddle_spots = fbm(SIZE, octaves=3, base_scale=150, seed=42)
oil_masks = (puddle_spots > 0.65).astype(np.float32) * (puddle_spots - 0.65) * 2.8

# Color blending: industrial grey-brown with dark grease stains
concrete_base = np.array([0.22, 0.22, 0.24], dtype=np.float32)
concrete_dark = np.array([0.14, 0.14, 0.15], dtype=np.float32)
concrete_stain = np.array([0.08, 0.07, 0.06], dtype=np.float32)

albedo_conc = (
    concrete_base[None, None, :] * (0.8 + 0.3 * base_grain[:, :, None]) +
    concrete_dark[None, None, :] * (large_stains[:, :, None] * 0.4)
)
# Add dark oil stains
albedo_conc = albedo_conc * (1.0 - oil_masks[:, :, None] * 0.7) + concrete_stain[None, None, :] * (oil_masks[:, :, None] * 0.7)
save_image((albedo_conc * 255).clip(0, 255), "concrete_floor_albedo.png")

# Height & Normal
conc_height = base_grain * 0.4 + large_stains * 0.3 - oil_masks * 0.2
save_image(height_to_normal(conc_height, strength=4.0), "concrete_floor_normal.png")

# Roughness: dry concrete is rough (0.85 - 0.95), oil stains are glossy (0.25)
conc_roughness = 0.82 + 0.15 * base_grain - oil_masks * 0.65
conc_roughness = np.clip(conc_roughness, 0.15, 0.98)
save_image(conc_roughness, "concrete_floor_roughness.png")

# ----------------------------------------------------
# 2. INDUSTRIAL WALL (Peeling paint, water drips, damp concrete)
# ----------------------------------------------------
print("2. Industrial Wall...")
wall_plaster = fbm(SIZE, octaves=6, base_scale=80, seed=88)
paint_peel_noise = fbm(SIZE, octaves=4, base_scale=300, seed=99)
drips = np.abs(np.sin(np.linspace(0, 16 * np.pi, SIZE)[None, :])) * fbm(SIZE, octaves=3, base_scale=200, seed=77)
# Peeling paint mask
peel_mask = (paint_peel_noise > 0.58).astype(np.float32)

# Colors: muted industrial olive-grey paint, darker damp concrete underneath
painted_color = np.array([0.28, 0.30, 0.27], dtype=np.float32)
exposed_color = np.array([0.16, 0.16, 0.17], dtype=np.float32)
grime_color = np.array([0.09, 0.09, 0.08], dtype=np.float32)

albedo_wall = (
    painted_color[None, None, :] * (1.0 - peel_mask[:, :, None]) +
    exposed_color[None, None, :] * (peel_mask[:, :, None])
)
# Add plaster micro-variation & drip stains
albedo_wall = albedo_wall * (0.85 + 0.25 * wall_plaster[:, :, None]) - (drips[:, :, None] * 0.12)
save_image((albedo_wall * 255).clip(0, 255), "industrial_wall_albedo.png")

# Normal: paint edge creates raised ridge
wall_height = wall_plaster * 0.35 + peel_mask * 0.65
save_image(height_to_normal(wall_height, strength=5.0), "industrial_wall_normal.png")

# Roughness: paint is semi-matte (0.6), exposed concrete is rough (0.9)
wall_roughness = (1.0 - peel_mask) * 0.62 + peel_mask * 0.88 + wall_plaster * 0.1
save_image(np.clip(wall_roughness, 0.2, 0.98), "industrial_wall_roughness.png")

# ----------------------------------------------------
# 3. ELEVATOR METAL & CABIN (Brushed steel, scratches)
# ----------------------------------------------------
print("3. Elevator Cabin Metal...")
# Brushed directional streak noise
brush_lines = np.repeat(np.random.rand(SIZE, 1), SIZE, axis=1).astype(np.float32)
brush_fine = fbm(SIZE, octaves=4, base_scale=64, seed=51)
scratches = (fbm(SIZE, octaves=6, base_scale=16, seed=61) > 0.75).astype(np.float32)

steel_color = np.array([0.42, 0.44, 0.46], dtype=np.float32)
tarnish_color = np.array([0.22, 0.20, 0.18], dtype=np.float32)
tarnish_mask = fbm(SIZE, octaves=3, base_scale=400, seed=33)

albedo_steel = steel_color[None, None, :] * (0.9 + 0.15 * brush_lines[:, :, None] * brush_fine[:, :, None])
albedo_steel = albedo_steel * (1.0 - tarnish_mask[:, :, None] * 0.35) + tarnish_color[None, None, :] * (tarnish_mask[:, :, None] * 0.35)
save_image((albedo_steel * 255).clip(0, 255), "elevator_metal_albedo.png")

steel_height = brush_lines * 0.2 + scratches * 0.4
save_image(height_to_normal(steel_height, strength=3.0), "elevator_metal_normal.png")

steel_roughness = 0.30 + 0.15 * brush_lines + tarnish_mask * 0.35 + scratches * 0.3
save_image(np.clip(steel_roughness, 0.15, 0.85), "elevator_metal_roughness.png")

# ----------------------------------------------------
# 4. DIAMOND PLATE (Anti-slip steel floor for elevator)
# ----------------------------------------------------
print("4. Diamond Plate...")
# Procedural 45-degree diamond tread pattern
x_grid = np.linspace(0, 32 * np.pi, SIZE)
y_grid = np.linspace(0, 32 * np.pi, SIZE)
X, Y = np.meshgrid(x_grid, y_grid)

# Crossed lozenge pattern
tread1 = np.sin(X + Y) * np.cos(X - Y)
tread2 = np.sin(X - Y) * np.cos(X + Y)
diamond_pattern = np.maximum((tread1 > 0.3).astype(np.float32) * tread1, (tread2 > 0.3).astype(np.float32) * tread2)
diamond_pattern = (diamond_pattern - diamond_pattern.min()) / (diamond_pattern.max() - diamond_pattern.min() + 1e-6)
diamond_pattern = np.clip(diamond_pattern * 1.5, 0.0, 1.0)

plate_base = np.array([0.28, 0.30, 0.32], dtype=np.float32)
plate_raised = np.array([0.48, 0.50, 0.53], dtype=np.float32)
rust_dirt = np.array([0.18, 0.12, 0.08], dtype=np.float32)
plate_dirt_mask = fbm(SIZE, octaves=4, base_scale=200, seed=71)

albedo_plate = (
    plate_base[None, None, :] * (1.0 - diamond_pattern[:, :, None]) +
    plate_raised[None, None, :] * (diamond_pattern[:, :, None])
)
# Add grime in recesses
albedo_plate = albedo_plate * (1.0 - plate_dirt_mask[:, :, None] * (1.0 - diamond_pattern[:, :, None]) * 0.5)
save_image((albedo_plate * 255).clip(0, 255), "diamond_plate_albedo.png")

plate_height = diamond_pattern * 0.8 + fbm(SIZE, octaves=5, base_scale=64, seed=15) * 0.1
save_image(height_to_normal(plate_height, strength=8.0), "diamond_plate_normal.png")

# Raised parts are polished shiny (0.2), recesses are dirty (0.65)
plate_roughness = (1.0 - diamond_pattern) * 0.65 + diamond_pattern * 0.22 + plate_dirt_mask * 0.15
save_image(np.clip(plate_roughness, 0.18, 0.85), "diamond_plate_roughness.png")

# ----------------------------------------------------
# 5. RUSTED IRON (Pipes, brackets, terminal casing)
# ----------------------------------------------------
print("5. Rusted Iron...")
rust_noise = fbm(SIZE, octaves=6, base_scale=120, seed=105)
pitting_noise = fbm(SIZE, octaves=5, base_scale=40, seed=106)
rust_mask = (rust_noise > 0.45).astype(np.float32)

dark_iron = np.array([0.20, 0.21, 0.22], dtype=np.float32)
orange_rust = np.array([0.44, 0.22, 0.10], dtype=np.float32)
deep_rust = np.array([0.26, 0.12, 0.06], dtype=np.float32)

albedo_rust = (
    dark_iron[None, None, :] * (1.0 - rust_mask[:, :, None]) +
    (orange_rust[None, None, :] * 0.7 + deep_rust[None, None, :] * 0.3) * (rust_mask[:, :, None])
)
albedo_rust = albedo_rust * (0.85 + 0.25 * pitting_noise[:, :, None])
save_image((albedo_rust * 255).clip(0, 255), "rusted_iron_albedo.png")

rust_height = (1.0 - rust_mask) * 0.5 + rust_mask * (0.3 + 0.35 * pitting_noise)
save_image(height_to_normal(rust_height, strength=6.0), "rusted_iron_normal.png")

rust_roughness = (1.0 - rust_mask) * 0.35 + rust_mask * (0.85 + 0.12 * pitting_noise)
save_image(np.clip(rust_roughness, 0.25, 0.98), "rusted_iron_roughness.png")

# ----------------------------------------------------
# 6. CORRUGATED CEILING (Steel panels with rivet seams)
# ----------------------------------------------------
print("6. Corrugated Ceiling...")
# Ridged corrugated waves along Y axis
wave = (np.sin(np.linspace(0, 32 * np.pi, SIZE)) * 0.5 + 0.5)[:, None]
wave = np.repeat(wave, SIZE, axis=1).astype(np.float32)
metal_grain = fbm(SIZE, octaves=5, base_scale=64, seed=80)

dark_steel = np.array([0.15, 0.16, 0.18], dtype=np.float32)
steel_highlight = np.array([0.28, 0.30, 0.33], dtype=np.float32)

albedo_ceiling = (
    dark_steel[None, None, :] * (1.0 - wave[:, :, None] * 0.4) +
    steel_highlight[None, None, :] * (wave[:, :, None] * 0.4)
) * (0.9 + 0.15 * metal_grain[:, :, None])
save_image((albedo_ceiling * 255).clip(0, 255), "corrugated_ceiling_albedo.png")

ceiling_height = wave * 0.75 + metal_grain * 0.1
save_image(height_to_normal(ceiling_height, strength=7.0), "corrugated_ceiling_normal.png")

ceiling_roughness = 0.38 + 0.15 * wave + 0.1 * metal_grain
save_image(np.clip(ceiling_roughness, 0.2, 0.75), "corrugated_ceiling_roughness.png")

# ----------------------------------------------------
# 7. HAZARD STRIPES (Yellow & Black 45-degree safety stripes)
# ----------------------------------------------------
print("7. Hazard Safety Stripes...")
diag = (X + Y) * 2.0
stripes = (np.sin(diag) > 0.0).astype(np.float32)
scuff_noise = fbm(SIZE, octaves=6, base_scale=48, seed=333)
scuff_mask = (scuff_noise > 0.65).astype(np.float32)

hazard_yellow = np.array([0.88, 0.72, 0.08], dtype=np.float32)
hazard_black = np.array([0.10, 0.10, 0.11], dtype=np.float32)
hazard_scuff = np.array([0.22, 0.20, 0.18], dtype=np.float32)

albedo_hazard = (
    hazard_yellow[None, None, :] * stripes[:, :, None] +
    hazard_black[None, None, :] * (1.0 - stripes[:, :, None])
)
# Add paint scuffs & metal showing through
albedo_hazard = albedo_hazard * (1.0 - scuff_mask[:, :, None] * 0.6) + hazard_scuff[None, None, :] * (scuff_mask[:, :, None] * 0.6)
save_image((albedo_hazard * 255).clip(0, 255), "hazard_stripe_albedo.png")

hazard_height = stripes * 0.1 - scuff_mask * 0.35 + fbm(SIZE, octaves=4, base_scale=128, seed=4) * 0.1
save_image(height_to_normal(hazard_height, strength=3.0), "hazard_stripe_normal.png")

hazard_roughness = 0.45 + scuff_mask * 0.4 + fbm(SIZE, octaves=4, base_scale=96, seed=5) * 0.1
save_image(np.clip(hazard_roughness, 0.3, 0.9), "hazard_stripe_roughness.png")

print("All PBR Textures successfully generated!")
