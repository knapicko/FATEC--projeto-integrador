"""Gera as camadas da caixa do tutorial (ferramentas inteiras que pulam).

    pip install pillow numpy scipy
    python tool/gerar_caixa_tutorial.py

Usa a caixa da tela inicial (assets/images/caixa_animacao/transparente/), que
tem a MESMA caixa e o mesmo rosto da caixa falante, só que separada em
camadas, e as ferramentas inteiras (ferramentas.png):

  fundo.png            tampa + interior da caixa aberta (o "fundo" que
                       aparece quando as ferramentas pulam);
  ferramenta_<n>.png   cada ferramenta: 0 chave inglesa, 1 chave de fenda,
                       2 martelo;
  ferramenta_<n>_contorno.png
                       a ferramenta engordada: o app usa para "vazar" a linha
                       em volta dela (como as outras linhas do desenho);
  frente_<quadro>.png  frente + lateral da caixa com o rosto de cada quadro da
                       fala (assets/images/caixa/fala/);
  frente_mascara.png   silhueta da frente: apaga o que fica atrás dela (a
                       parte de baixo das ferramentas, "dentro" da caixa).

Todas no mesmo quadro 500×500.
"""
import glob
import os
import shutil

import numpy as np
from PIL import Image, ImageFilter
from scipy import ndimage

ORIGEM = 'assets/images/caixa_animacao/transparente'
FALA = 'assets/images/caixa/fala'
NORMAL = 'assets/images/caixa/caixa_normal.png'
DESTINO = 'assets/images/caixa/tutorial'
# Regiões de ferramentas.png: 1 chave inglesa; 2+4 chave de fenda (ponta e
# cabo); 3+5 martelo (cabeça e cabo).
GRUPOS = [[1], [2, 4], [3, 5]]
CONTORNO = 6  # px: a grossura das linhas da caixa


def rgba(caminho):
    return np.array(Image.open(caminho).convert('RGBA'))


# Limpa as camadas antigas.
if os.path.isdir(DESTINO):
    shutil.rmtree(DESTINO)
os.makedirs(DESTINO)

shutil.copy(f'{ORIGEM}/caixa_aberta_fundo.png', f'{DESTINO}/fundo.png')
shutil.copy(f'{ORIGEM}/caixa_aberta_frente_mascara.png',
            f'{DESTINO}/frente_mascara.png')

# Ferramentas.
fer = rgba(f'{ORIGEM}/ferramentas.png')
rotulos, _ = ndimage.label(fer[:, :, 3] > 100)
centros = []
for i, grupo in enumerate(GRUPOS):
    nucleo = np.isin(rotulos, grupo)
    m = ndimage.binary_dilation(nucleo, iterations=2) & (fer[:, :, 3] > 0)
    outras = (rotulos > 0) & ~nucleo
    m &= ~outras
    fill = np.zeros_like(fer)
    fill[m] = fer[m]
    Image.fromarray(fill).save(f'{DESTINO}/ferramenta_{i}.png')

    gordo = ndimage.binary_dilation(nucleo, iterations=CONTORNO)
    cont = Image.fromarray((gordo * 255).astype(np.uint8), 'L').filter(
        ImageFilter.GaussianBlur(0.8))
    c = np.zeros((*fer.shape[:2], 4), dtype=np.uint8)
    c[:, :, :3] = 255
    c[:, :, 3] = np.array(cont)
    Image.fromarray(c).save(f'{DESTINO}/ferramenta_{i}_contorno.png')
    ys, xs = np.where(nucleo)
    centros.append((round(float(xs.mean()), 1), round(float(ys.mean()), 1)))

# Frente com o rosto de cada quadro da fala. A região do rosto é a face da
# frente da caixa falante (preenchida, com os furos dos olhos e da boca).
frente = rgba(f'{ORIGEM}/caixa_aberta_frente.png')
normal = rgba(NORMAL)
rot_n, _ = ndimage.label(normal[:, :, 3] > 100)
maior = np.argmax(np.bincount(rot_n.ravel())[1:]) + 1  # a face (maior região)
rosto = ndimage.binary_fill_holes(rot_n == maior)
rosto = ndimage.binary_erosion(rosto, iterations=3)
for f in sorted(glob.glob(f'{FALA}/*.png')):
    q = rgba(f)
    saida = frente.copy()
    saida[rosto] = q[rosto]
    Image.fromarray(saida).save(f'{DESTINO}/frente_{os.path.basename(f)}')

print('ok — centros das ferramentas:', centros)
