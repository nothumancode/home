-- A Vercel-inspired Base16 scheme: Geist neutrals and accessible accents.
-- Neovim reloads the active colorscheme when 'background' changes.
local light = vim.o.background == "light"
local palette = light
		and {
			base00 = "#FFFFFF",
			base01 = "#FAFAFA",
			base02 = "#EBEBEB",
			base03 = "#666666",
			base04 = "#525252",
			base05 = "#171717",
			base06 = "#0A0A0A",
			base07 = "#000000",
			base08 = "#C50000",
			base09 = "#A35200",
			base0A = "#805500",
			base0B = "#067A45",
			base0C = "#007080",
			base0D = "#005FCC",
			base0E = "#7820BC",
			base0F = "#AD2860",
		}
	or {
		base00 = "#0A0A0A",
		base01 = "#171717",
		base02 = "#333333",
		base03 = "#888888",
		base04 = "#A1A1A1",
		base05 = "#EDEDED",
		base06 = "#FAFAFA",
		base07 = "#FFFFFF",
		base08 = "#FF6166",
		base09 = "#FFAB70",
		base0A = "#F5C65B",
		base0B = "#50E3A4",
		base0C = "#79E7EE",
		base0D = "#52A8FF",
		base0E = "#BF8BFF",
		base0F = "#FF8BC2",
	}

require("mini.base16").setup({ palette = palette })
vim.g.colors_name = "vercel"
