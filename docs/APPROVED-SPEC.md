# SmithMk Flutter Dashboard — APPROVED SPEC (March 2026)

## APPROVED DEMO
Live at: https://smithmk-demo.vercel.app
Source: /home/claude/demo-deploy/index.html

## WHAT WAS APPROVED
Mark approved the HTML demo. Now build it in Flutter using Flutter's full power.

## CRITICAL REQUIREMENTS FROM THIS SESSION

### Navigation
- **Side rail** (68px) — tablet/desktop/landscape. Icons8 3D icons. Active item amber left bar.
- **Bottom nav** (5 items) — phone portrait only.
- Pages: Dashboard, Rooms, Lights, Climate, Blinds, Security, Energy, Media, Settings

### Dashboard Cards (glassmorphic)
- Background gradient (linear-gradient 145deg, rgba white 0.05 to 0.02)
- Backdrop blur 14px
- 1px border rgba white 0.07
- Top edge highlight (1px gradient line)
- Inner top gradient (40%, rgba white 0.03 to transparent)
- Box shadow: 0 8px 32px rgba black 0.3, inset 0 1px 0 rgba white 0.04
- Border radius 20px, padding 20px
- Hover: lift -1px, deeper shadow, brighter border
- **Drag and drop to reorder** using HTML5 drag API (in Flutter: ReorderableListView or custom)

### Thermostat
- 3D bevelled ring: outer shadow, gradient bezel (#2c2c2c to #0e0e0e), specular highlight
- Dark matte inner face (radial gradient #1a1a1a to #0c0c0c)
- Temperature arc: blue(12°) → amber(22°) → orange(30°) gradient segments
- Glow behind thumb dot
- Draggable with pointer events
- **ON = bright arc, glow, white text**
- **OFF = arc disappears, text dims to #444, bezel darkens, ticks fade**
- 3D power button: bevelled gradient, inset highlight, orange glow when on, CSS power icon
- 3D +/- buttons: same bevelled treatment
- Heat/Cool toggle pill

### Room Lights
- Click room row → **MODAL POPUP** (not expand)
- Modal: dark glass box (linear-gradient 145deg), border, top edge highlight, box shadow
- Contains: emoji, room name, ON/OFF toggle, vertical slider, percentage, presets (25/50/75/100%)
- Vertical slider: recessed dark track, amber fill (dim to bright), thumb with grip line
- Pointer events for dragging (setPointerCapture in HTML = onPanUpdate in Flutter)
- Close: X button or tap backdrop

### Energy Gauges
- 100px diameter (BIGGER than before)
- Syncfusion radial gauges
- 8px thick arcs, rounded ends
- Glass inner ring effect (inset shadow)
- Solar (amber), Battery (green), Home (blue), EV (amber)
- Value text in centre, label below

### Scenes
- Horizontal scroll on portrait
- 3x2 grid on landscape
- Icons8 3D icons
- Active: amber background, amber border, amber text
- Inactive: transparent, subtle border

### Status Cards (2x2 grid)
- Security (shield), Lights (bulb), EV (car), Blinds (curtains)
- Icons8 3D Fluency icons
- Glass sub-cards with top gradient and edge highlight

### Irrigation (with zones)
- Front Lawn, Garden Beds, Rear Lawn, Veggie Patch
- Duration per zone
- IDLE/RUNNING status
- RUN ALL button

### Responsive
- Phone portrait: single column, bottom nav, bigger thermostat
- Phone landscape: two columns, side rail 58px, compact thermostat 180px
- Tablet portrait: two columns, side rail
- Tablet landscape: two columns, side rail, compact climate, stretched status
- Desktop: two columns, side rail 68px, max width 1100px
- **Landscape: scenes first (3x2), weather second (compact)**

### Status Pills
- HA, SUPABASE, SOLAR — on EVERY page, not just home
- Glassmorphic pill with blur, dot colour (green/red)

### Icons
- Icons8 3D Fluency: sun, clapperboard, fire, shield, idea, car, lightning-bolt, curtains, bell, watering-can, door, document, dashboard, music, gear
- Use `cached_network_image` or `Image.network` in Flutter

### Colours (FROM THE BIBLE)
- Background: #121212 (NOT navy, NOT pure black)
- Cards: #1E1E1E to #252525
- Accent: #FFB300 (amber) — sparingly
- Gold: #c4a96b (branding/labels)
- Inactive: #4A4A4A
- Text primary: #EEEEEE (off-white)
- Text secondary: #B0B0B0
- Text tertiary: #707070
- Status dots only: green #4ADE80, red #F87171
- Heating: #FF6B35
- BANNED: no navy, no blue, no purple, no teal

### Font
- DM Sans (approved in demo) — or Inter as fallback
- Medium to Bold only, NEVER thin on dark

### Animations
- 200-500ms duration
- Spring physics: Curves.easeInOutCubicEmphasized
- Staggered fade+slide entry for cards
- Haptic feedback on every interaction

## ROOMS PAGE REQUIREMENTS (NOT YET APPROVED - IN PROGRESS)

### Flow
1. Room starts as EMPTY canvas
2. Tap "Add Room" → opens a FULL PAGE (not modal) showing ALL available HA devices with checkboxes
   - Every light entity from HA
   - Every blind entity from HA  
   - Ducted aircon (NOT split system)
   - Radiators
   - Media devices
   - Sensors
3. Tick the devices you want in this room → creates the room
4. Multiple rooms = horizontal swipe carousel (PageView in Flutter)
5. Dot indicators showing which room you're on

### Device Controls (tap to open)
- **Tap a light** → vertical dimmer modal popup (MUST match the approved dashboard dimmer exactly — same amber fill, same thumb, same colours, same pointer drag)
- **Tap a blind** → blind visual modal showing the blind opening/closing with fabric animation (ORIGINAL design, NOT a copy of the PWA BlindVisual)
- **Tap aircon** → temperature control
- **Tap media** → media controls

### Critical Rules
- Navigation (side rail/bottom nav) lives in AppShell ONLY — individual pages do NOT include nav
- Dimmer slider MUST match the dashboard approved version exactly
- Ducted aircon, NOT split system
- All neumorphic dark styling matching dashboard
- Monochrome Phosphor icons throughout, emoji only for room avatars and scenes
