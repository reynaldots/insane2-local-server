"""
Extrator de arquivos .pak (formato TPAK v4) do Insane 2.

Uso:
    py tools/tpak_extract.py <arquivo.pak> [pasta_saida] [--list] [--filter texto]

Formato (engenharia reversa do i2.exe, rotina em 0x430bb0):
    - Cabeçalho: "TPAK", versão (4), reservado, quantidade de arquivos
    - Dword ofuscado (~v >> 2 == 4)
    - Bloco de nomes: tamanho descompactado, tamanho compactado, zlib
      (primeiro dword do bloco sofre XOR com a quantidade de arquivos)
    - Índice ordenado (count * uint32), tabela de chunks (n + n * uint32)
    - Tabela de arquivos: zlib (primeiro dword XOR com tamanho compactado + count),
      entradas de 28 bytes
    - Dados: começam logo após a tabela, alinhados em 4 bytes
"""

import os
import struct
import sys
import zlib

#region Leitura do pak

ENTRY_SIZE = 28


def align4(f):
    # Alinha a posição do arquivo em múltiplo de 4
    pos = f.tell()
    f.seek((pos + 3) & ~3)


def read_u32(f):
    return struct.unpack('<I', f.read(4))[0]


def unxor_inflate(data, key):
    # Desfaz o XOR do primeiro dword e descompacta com zlib
    buf = bytearray(data)
    first = struct.unpack_from('<I', buf, 0)[0] ^ (key & 0xFFFFFFFF)
    struct.pack_into('<I', buf, 0, first)
    return zlib.decompress(bytes(buf))


def decode_names(raw, count):
    # Cada nome: uint32 tamanho + bytes ofuscados + \0
    # Byte j do nome i: XOR com 2*(tamanho + j) + (tamanho % 5) + i
    names_by_offset = {}
    pos = 0
    for i in range(count):
        length = struct.unpack_from('<I', raw, pos)[0]
        start = pos + 4
        key = (length % 5) + i
        chars = bytes(
            (raw[start + j] ^ ((2 * (length + j) + key) & 0xFF)) for j in range(length)
        )
        names_by_offset[start] = chars.decode('latin-1')
        pos = start + length + 1
    return names_by_offset


class TPak:
    def __init__(self, path):
        self.path = path
        self.f = open(path, 'rb')
        self._read_header()

    def _read_header(self):
        f = self.f

        # Cabeçalho fixo
        magic, version, _reserved, count = struct.unpack('<4sIII', f.read(16))
        if magic != b'TPAK' or version != 4:
            raise ValueError(f'{self.path}: não é um TPAK v4')
        self.count = count

        # Dword de verificação ofuscado
        check = (~read_u32(f) & 0xFFFFFFFF) >> 2
        if check != 4:
            raise ValueError(f'{self.path}: verificação do cabeçalho falhou ({check})')

        # Bloco de nomes compactado
        names_usize = read_u32(f)
        names_csize = read_u32(f)
        names_raw = unxor_inflate(f.read(names_csize), count)
        if len(names_raw) != names_usize:
            raise ValueError('Tamanho do bloco de nomes não confere')
        names = decode_names(names_raw, count)
        align4(f)

        # Índice ordenado e tabela de chunks (para arquivos grandes)
        f.read(count * 4)
        chunk_words = read_u32(f)
        self.chunks = struct.unpack(f'<{chunk_words}I', f.read(chunk_words * 4)) if chunk_words else ()

        # Tabela de arquivos compactada
        table_usize = read_u32(f)
        table_csize = read_u32(f)
        table = unxor_inflate(f.read(table_csize), table_csize + count)
        if len(table) != table_usize:
            raise ValueError('Tamanho da tabela de arquivos não confere')
        align4(f)
        self.data_base = f.tell()

        # Monta a lista de entradas
        self.entries = []
        for i in range(count):
            usize, csize, chunk_idx, offset, name_off, _a, _b = struct.unpack_from(
                '<IIiIIII', table, i * ENTRY_SIZE
            )
            self.entries.append({
                'name': names.get(name_off + 4, names.get(name_off, f'__unnamed_{i}')),
                'usize': usize,
                'csize': csize,
                'chunk': chunk_idx,
                'offset': offset,
            })

    def read(self, entry):
        # Lê o conteúdo de um arquivo (armazenado, zlib único ou em chunks)
        self.f.seek(self.data_base + entry['offset'])
        if entry['usize'] == entry['csize']:
            return self.f.read(entry['usize'])

        if entry['chunk'] == -1:
            return zlib.decompress(self.f.read(entry['csize']))

        # Chunks: [quantidade, (tam_descompactado, tam_compactado) * quantidade]
        idx = entry['chunk']
        n = self.chunks[idx]
        out = bytearray()
        for k in range(n):
            usz = self.chunks[idx + 1 + k * 2]
            csz = self.chunks[idx + 2 + k * 2]
            part = self.f.read(csz)
            out += part if usz == csz else zlib.decompress(part)
        return bytes(out)

#endregion

#region CLI


def main():
    args = [a for a in sys.argv[1:] if not a.startswith('--')]
    flags = sys.argv[1:]
    if not args:
        print(__doc__)
        return 1

    pak = TPak(args[0])
    out_dir = args[1] if len(args) > 1 else os.path.join(os.path.dirname(__file__), 'extracted')

    # Filtro opcional por trecho do nome
    filt = None
    if '--filter' in flags:
        filt = flags[flags.index('--filter') + 1].lower()

    for e in pak.entries:
        if filt and filt not in e['name'].lower():
            continue

        # Apenas lista os arquivos
        if '--list' in flags:
            print(f"{e['usize']:>10} {e['csize']:>10} {e['name']}")
            continue

        # Extrai preservando a estrutura de pastas
        dest = os.path.join(out_dir, e['name'].replace('\\', '/'))
        os.makedirs(os.path.dirname(dest) or '.', exist_ok=True)
        with open(dest, 'wb') as o:
            o.write(pak.read(e))
        print(dest)
    return 0


if __name__ == '__main__':
    sys.exit(main())

#endregion
