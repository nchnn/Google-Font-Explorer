import 'package:material_ui/material_ui.dart';
import '../models/font_model.dart';

const commonWeights = <FontWeight>[
  FontWeight.w300,
  FontWeight.w400,
  FontWeight.w500,
  FontWeight.w600,
  FontWeight.w700,
];

const standardVariants = <String>[
  '300',
  'regular',
  '500',
  '600',
  '700',
];

/// Bundled font catalogue used as starter fonts and offline fallback.
const availableFonts = <FontModel>[
  FontModel(
    name: 'Roboto',
    category: 'Sans Serif',
    description: 'A clean and versatile everyday typeface.',
    weights: commonWeights,
    variants: standardVariants,
    files: {
      'regular': 'https://fonts.gstatic.com/s/roboto/v30/KFOmCnqEu92Fr1Mu4mxKKTU1Kg.ttf',
      '700': 'https://fonts.gstatic.com/s/roboto/v30/KFOlCnqEu92Fr1MmWUlfBBc4AMP6lQ.ttf',
    },
  ),
  FontModel(
    name: 'Poppins',
    category: 'Geometric Sans',
    description: 'Rounded geometric shapes with a modern feel.',
    weights: commonWeights,
    variants: standardVariants,
    files: {
      'regular': 'https://fonts.gstatic.com/s/poppins/v20/pxiEyp8kv8JHgFVrFJA.ttf',
    },
  ),
  FontModel(
    name: 'Montserrat',
    category: 'Geometric Sans',
    description: 'Strong, contemporary lettering for headlines and UI.',
    weights: commonWeights,
    variants: standardVariants,
    files: {
      'regular': 'https://fonts.gstatic.com/s/montserrat/v25/JTUSjIg1_i6t8kCHKm459Wlhyw.ttf',
    },
  ),
  FontModel(
    name: 'Open Sans',
    category: 'Humanist Sans',
    description: 'Friendly and highly readable at many sizes.',
    weights: commonWeights,
    variants: standardVariants,
    files: {
      'regular': 'https://fonts.gstatic.com/s/opensans/v34/memSYaGs126MiZpBA-UvWbX2vVnXBbObj2OVZyOOSr4dVJWUgsjZ0B4gaVQUwaEQbjA.ttf',
    },
  ),
  FontModel(
    name: 'Lato',
    category: 'Sans Serif',
    description: 'Warm, balanced, and comfortable for long reading.',
    weights: commonWeights,
    variants: standardVariants,
    files: {
      'regular': 'https://fonts.gstatic.com/s/lato/v24/S6uyw4BMUTPHjx4wXiWtFCc.ttf',
    },
  ),
  FontModel(
    name: 'Nunito',
    category: 'Rounded Sans',
    description: 'Soft rounded terminals and approachable character.',
    weights: commonWeights,
    variants: standardVariants,
    files: {
      'regular': 'https://fonts.gstatic.com/s/nunito/v25/XRXI3I6Li01BKofiOc5wtlZ2di8HDLshdTQ3jw.ttf',
    },
  ),
  FontModel(
    name: 'Raleway',
    category: 'Sans Serif',
    description: 'An elegant family with distinctive letterforms.',
    weights: commonWeights,
    variants: standardVariants,
    files: {
      'regular': 'https://fonts.gstatic.com/s/raleway/v28/1Ptxg8zYS_SKggPN4iEgvnHyvveLxVvaorCFPrcVIT9d0c8.ttf',
    },
  ),
  FontModel(
    name: 'Oswald',
    category: 'Condensed Sans',
    description: 'A compact display style for bold statements.',
    weights: commonWeights,
    variants: standardVariants,
    files: {
      'regular': 'https://fonts.gstatic.com/s/oswald/v49/TK3_WkUHHAIjg75cFRf3bXL8LICs13FvgUFoZAaRliE.ttf',
    },
  ),
  FontModel(
    name: 'Merriweather',
    category: 'Serif',
    description: 'A sturdy serif designed for comfortable reading.',
    weights: commonWeights,
    variants: standardVariants,
    files: {
      'regular': 'https://fonts.gstatic.com/s/merriweather/v30/u-440qyYrRw-PfUBy7mq9HNfc4-lldUb.ttf',
    },
  ),
  FontModel(
    name: 'Playfair Display',
    category: 'Display Serif',
    description: 'High contrast and editorial-inspired elegance.',
    weights: commonWeights,
    variants: standardVariants,
    files: {
      'regular': 'https://fonts.gstatic.com/s/playfairdisplay/v30/nuFvD-vYSZviVYUb_rj3ij__anPXJzDwcbmjWBN2PKdFvXDXbtM.ttf',
    },
  ),
  FontModel(
    name: 'Inter',
    category: 'Sans Serif',
    description: 'A practical interface typeface with clear shapes.',
    weights: commonWeights,
    variants: standardVariants,
    files: {
      'regular': 'https://fonts.gstatic.com/s/inter/v12/UcCO3FwrK3iLTeHuS_fvQtMwCp50KnMw2boKoduKmMEVuLyfAZ9hjp-Ek-_EeA.ttf',
    },
  ),
  FontModel(
    name: 'Ubuntu',
    category: 'Humanist Sans',
    description: 'Distinctive, friendly, and open letterforms.',
    weights: commonWeights,
    variants: standardVariants,
    files: {
      'regular': 'https://fonts.gstatic.com/s/ubuntu/v20/4iCs6KVjbNBYlgoKcg72nU6AF7xm.ttf',
    },
  ),
];
