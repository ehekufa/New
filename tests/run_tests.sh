#!/bin/sh
# Самотесты порта: C-часть (PNG/inflate), конвертер, Lua-синтаксис, движок.
set -u           # без -e: каждый шаг сам сообщает о провале через check

ROOT=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
cd "$ROOT"
BIN=build/cb-classic
FAILED=0

# сохранение и «firebase» — во временном файле: тесты идут с чистого листа и не
# трогают прогресс игрока (saves/db.tsv)
CB_STORE=/tmp/cb_saves_test.tsv
rm -f "$CB_STORE"
export CB_STORE

step() { printf '\n== %s ==\n' "$1"; }
check() {
  if [ "$1" -eq 0 ]; then
    printf '   OK\n'
  else
    printf '   ПРОВАЛ\n'
    FAILED=$((FAILED + 1))
  fi
}

step "сборка"
make -s -j4
check $?

step "иконка приложения: из assets/icon.png собраны все размеры и включены в манифест"
python3 tools/make_icon.py --check
check $?
grep -q 'android:icon="@mipmap/ic_launcher"' android/app/src/main/AndroidManifest.xml
check $?
grep -q 'android:roundIcon="@mipmap/ic_launcher_round"' android/app/src/main/AndroidManifest.xml
check $?
test -f android/app/src/main/res/mipmap-anydpi-v26/ic_launcher.xml
check $?

step "C: PNG-декодер на всех ассетах + round-trip"
cc -O2 -std=c11 -Isrc/c tests/c/test_png.c src/c/png.c src/c/inflate.c -o build/test_png
./build/test_png assets
check $?

step "инструменты: извлечение ассетов идемпотентно"
python3 tools/extract_assets.py --src original --out /tmp/cb_assets_check >/tmp/cb_extract.log 2>&1
check $?
grep -q "PNG: 128" /tmp/cb_extract.log
check $?

step "инструменты: конвертер покрывает все блоки"
python3 tools/catrobat2lua.py --src original --out /tmp/cb_lua_check >/tmp/cb_convert.log 2>&1
check $?
grep -q "неподдержанных блоков: 0" /tmp/cb_convert.log
check $?

step "Lua: синтаксис сгенерированных модулей"
$BIN --check generated/lua
check $?

step "движок: сцена «Загрузка» (42) стартует и переходит дальше"
$BIN --frames 40 --scene 42 --out /tmp/cb_frames_42 >/tmp/cb_run42.log 2>&1
check $?
grep -q "сцена: 42" /tmp/cb_run42.log
check $?

step "движок: меню (1) рисует спрайты"
$BIN --frames 10 --scene 1 --out /tmp/cb_frames_1 --verbose >/tmp/cb_run1.log 2>&1
check $?
grep -q "спрайтов на сцене: 9" /tmp/cb_run1.log
check $?

step "движок: игра (26) с профилем и вводом джойстика"
# первые ~3 с боя занимает видео-интро, поэтому ввод в сценариях начинается
# после кадра 100
$BIN --frames 160 --scene 26 --script tests/scripts/joystick.txt \
     --profile "3=100,4=6,12=1" --out /tmp/cb_frames_26 >/tmp/cb_run26.log 2>&1
check $?
grep -q "ошибок: 0" /tmp/cb_run26.log
check $?

step "управление: джойстик ведёт игрока вправо, а не вверх"
$BIN --frames 150 --scene 26 --script tests/scripts/joystick_move.txt \
     --profile "3=100,4=6,12=1" --out /tmp/cb_frames_joy --verbose \
     >/tmp/cb_joy.log 2>&1
check $?
awk '/Игрок /{print $3}' /tmp/cb_joy.log | tail -1 | \
  python3 -c "import sys; sys.exit(0 if float(sys.stdin.read().strip() or 0) > 100 else 1)"
check $?

step "способности: кнопка «Супер атака» перезаряжается (своя пауза у всех классов)"
# 600 кадров: первые ~3 с занимает видео-интро, способность жмём после него
$BIN --frames 600 --scene 26 --profile "3=100,4=600,12=1,47=2" \
     --set-var "65=1@2" --script tests/scripts/super_attack.txt --trace 26 --bench 600 --no-sound \
     >/tmp/cb_cooldown.log 2>&1
check $?
grep -q "ярк= 85.0" /tmp/cb_cooldown.log
check $?
# 15 секунд при 30 fps — это ~450 серых кадров; нажатие во время паузы её не продлевает
DIM=$(grep -c "ярк= 85.0" /tmp/cb_cooldown.log || true)
if [ "$DIM" -ge 430 ] && [ "$DIM" -le 470 ]; then
  printf '   OK (серых кадров %s ≈ 15 с)\n' "$DIM"
else
  printf '   ПРОВАЛ: серых кадров %s, ждали ~450 (15 с)\n' "$DIM"
  FAILED=$((FAILED + 1))
fi
LAST=$(grep "id=26" /tmp/cb_cooldown.log | tail -1)
case "$LAST" in
  *"ярк=100.0"*) printf '   OK кнопка снова яркая\n' ;;
  *) printf '   ПРОВАЛ: кнопка осталась серой\n'; FAILED=$((FAILED + 1)) ;;
esac

step "атака: кнопка А срабатывает на палец и не залипает"
$BIN --frames 160 --scene 26 --profile "3=100,4=6,12=1,47=4" \
     --script tests/scripts/attack_hold.txt --trace 25 --no-sound \
     >/tmp/cb_aim.log 2>&1
check $?
# кнопка погасла — атака пошла
grep -q "trace  111 .*ярк= 85.0" /tmp/cb_aim.log
check $?
# через полсекунды кнопка снова яркая: атака не залипает
grep -q "trace  125 .*ярк=100.0" /tmp/cb_aim.log
check $?

step "изумруды: в меню счёт рядом с иконкой, белое число без подписи"
$BIN --frames 8 --scene 1 --set-var "93=12@3" --verbose >/tmp/cb_em.log 2>&1
check $?
# счёт рисует сама сцена прямо у зелёного изумруда (205,105), подписи нет
grep -q 'var:93 .*видно=1 значение="12"' /tmp/cb_em.log
check $?
if grep -q 'изумруды: 12\|Изумруды: 12' /tmp/cb_em.log; then
  printf '   ПРОВАЛ: у счётчика появилась подпись\n'
  FAILED=$((FAILED + 1))
else
  printf '   OK\n'
fi

step "изумруды: вне меню счётчика не видно (число — только в меню)"
for scene in 26 31 95; do
  $BIN --frames 8 --scene $scene --set-var "93=12@3" --verbose >/tmp/cb_em2.log 2>&1
  check $?
  if grep -q 'hud:изумруды' /tmp/cb_em2.log; then
    printf '   ПРОВАЛ: на сцене %s всё ещё висит счётчик изумрудов\n' "$scene"
    FAILED=$((FAILED + 1))
  else
    printf '   OK сцена %s — счётчика нет\n' "$scene"
  fi
done

step "скины: переменная «Скин» меняет картинку игрока"
$BIN --frames 6 --scene 26 --profile "12=2" --out /tmp/cb_frames_skin --verbose \
     >/tmp/cb_skin.log 2>&1
check $?
grep -q "Игрок .*0393_igrok_2.png" /tmp/cb_skin.log
check $?

step "кубки: победа даёт кубки, счёт сохраняется и виден в меню"
rm -f "$CB_STORE"
$BIN --frames 40 --scene 26 --profile "3=100,4=6,12=1" --set-var "4=0@10" \
     --out /tmp/cb_frames_cups --verbose >/tmp/cb_cups.log 2>&1
check $?
# в новой версии кубки начисляет сам проект: +10 за победу и сохранение
grep -q "var:24[[:space:]]*10019" "$CB_STORE"
check $?
# после заставки открывается регистрация — «Не хочу» ведёт в меню (как в старой версии)
$BIN --frames 200 --scene 42 --script tests/scripts/reg_skip.txt --verbose \
     >/tmp/cb_cups2.log 2>&1
check $?
grep -q 'var:24 .*значение="10019"' /tmp/cb_cups2.log
check $?

step "шрифт: используется Roboto из third_party/fonts"
$BIN --frames 2 --scene 1 --out /tmp/cb_frames_font --verbose >/tmp/cb_font.log 2>&1
check $?
grep -q "шрифт: .*Roboto-Regular.ttf" /tmp/cb_font.log
check $?

step "звук: играют эффекты проекта, фоновой музыки нет"
$BIN --frames 160 --scene 26 --script tests/scripts/joystick.txt \
     --profile "3=100,4=6,12=1" --out /tmp/cb_frames_snd \
     >/tmp/cb_snd.log 2>&1
check $?
grep -Eq "прозвучало звуков: [1-9]" /tmp/cb_snd.log
check $?
# музыки быть не должно: ни синтезатора в коде, ни флагов в CLI
if grep -rq "build_music\|start_music\|export_music" src/cpp; then
  printf '   ПРОВАЛ: в коде осталась музыка\n'
  FAILED=$((FAILED + 1))
else
  printf '   OK\n'
fi
$BIN --help >/tmp/cb_help.log 2>&1
if grep -q -- "--export-music" /tmp/cb_help.log; then
  printf '   ПРОВАЛ: флаг музыки остался в CLI\n'
  FAILED=$((FAILED + 1))
else
  printf '   OK\n'
fi

step "звук: нажатие кнопки меню щёлкает звуком из проекта"
printf 'f2: tap -400 40\n' > /tmp/cb_click.txt
$BIN --frames 8 --scene 1 --script /tmp/cb_click.txt --out /tmp/cb_frames_click \
     >/tmp/cb_click.log 2>&1
check $?
grep -Eq "прозвучало звуков: [1-9]" /tmp/cb_click.log
check $?

step "адаптация: суперсэмплинг сохраняет раскладку (2x кадр)"
$BIN --frames 3 --scene 31 --pixel-scale 2 --out /tmp/cb_frames_x2 >/tmp/cb_x2.log 2>&1
check $?
python3 - <<'PYW'
import struct, sys, glob
files = sorted(glob.glob("/tmp/cb_frames_x2/*.png"))
if not files:
    sys.exit(1)
data = open(files[-1], "rb").read(33)
w, h = struct.unpack(">II", data[16:24])
sys.exit(0 if (w, h) == (3000, 1440) else 1)
PYW
check $?

step "плавность: время кадра измеряется (--bench, без записи PNG)"
$BIN --scene 26 --bench 12 --no-sound >/tmp/cb_bench.log 2>&1
check $?
grep -Eq "бенч: .*fps" /tmp/cb_bench.log
check $?

step "ввод: все кнопки проекта получают нажатие"
$BIN --check-buttons >/tmp/cb_buttons.log 2>&1
check $?
grep -q "не получают нажатие: 0" /tmp/cb_buttons.log
check $?

step "ввод: кнопки меню переключают сцены"
$BIN --frames 12 --scene 1 --script tests/scripts/menu_buttons.txt \
     --out /tmp/cb_frames_menu >/tmp/cb_menu.log 2>&1
check $?
grep -q "сцена: 70 (Режимы)" /tmp/cb_menu.log
check $?

step "ввод: блок «спросить» (ask) возвращает ответ"
$BIN --frames 24 --scene 31 --profile "24=100,80=44" --script tests/scripts/ask_reset.txt \
     --out /tmp/cb_frames_ask --verbose >/tmp/cb_ask.log 2>&1
check $?
grep -q '= \[abc\]' /tmp/cb_ask.log
check $?

step "ввод: два пальца одновременно (джойстик + кнопка) не ломают игру"
$BIN --frames 130 --scene 26 --script tests/scripts/multitouch.txt \
     --profile "3=100,4=6,12=1" --out /tmp/cb_frames_mt >/tmp/cb_mt.log 2>&1
check $?
grep -q "ошибок: 0" /tmp/cb_mt.log
check $?

step "ввод: поле промокода на сцене «Больше» принимает текст с клавиатуры"
$BIN --frames 8 --scene 31 --profile "24=100" \
     --script tests/scripts/promo_type.txt --out /tmp/cb_frames_promo --verbose \
     >/tmp/cb_promo.log 2>&1
check $?
# ввод с клавиатуры попадает в поле, подсказки-слова «Промокод» в нём нет
grep -q 'Промокод .*значение="MurderOfLove"' /tmp/cb_promo.log
check $?
grep -q 'Промокод .*placeholder=""' /tmp/cb_promo.log
check $?
grep -q 'ввод подтверждён: Промокод = \[MurderOfLove\]' /tmp/cb_promo.log
check $?

step "промокоды: код «MurderOfLove» начисляет +45 кубков"
$BIN --frames 26 --scene 31 --profile "24=100" \
     --script tests/scripts/promo_input.txt --out /tmp/cb_frames_promo2 --verbose \
     >/tmp/cb_promo2.log 2>&1
check $?
# нажали «Ввести» — кубки выросли со 100 до 145 и видны в меню
grep -q 'var:24 .*значение="145"' /tmp/cb_promo2.log
check $?

step "сеть: без --fb-url сеть выключена (игра работает офлайн)"
$BIN --frames 5 --scene 1 --out /tmp/cb_frames_offline --verbose >/tmp/cb_offline.log 2>&1
check $?
grep -q "сеть: выключена" /tmp/cb_offline.log
check $?

step "сеть: Firebase RTDB — чтение базы игрой (эмулятор базы)"
FB_PORT=8899
cat > /tmp/cb_fb_seed.json <<'EOF'
{"world": {"X1": 42, "Y1": -7, "ROT1": 15, "Ивент": "тест"}}
EOF
rm -f /tmp/cb_fb_dump.json
python3 tests/firebase_mock.py --port "$FB_PORT" --seed /tmp/cb_fb_seed.json \
    --dump /tmp/cb_fb_dump.json >/tmp/cb_fb_mock.log 2>&1 &
FB_PID=$!
sleep 1
$BIN --scene 95 --frames 45 --fps 30 --realtime --out /tmp/cb_frames_fb \
     --fb-url "http://127.0.0.1:$FB_PORT/" --verbose >/tmp/cb_fb_read.log 2>&1
check $?
# игра прочитала из базы координаты кубов и название ивента
grep -q "база: .*X1=42" /tmp/cb_fb_read.log
check $?
grep -q "X1=42 Y1=-7" /tmp/cb_fb_read.log
check $?

step "сеть: запись в базу (сцена «Загрузка» пишет размер экрана)"
$BIN --scene 42 --frames 45 --fps 30 --realtime --out /tmp/cb_frames_fb42 \
     --fb-url "http://127.0.0.1:$FB_PORT/" >/tmp/cb_fb_write.log 2>&1
check $?
python3 tests/fb_check_write.py /tmp/cb_fb_dump.json "world/ScreenWidth" 1500
check $?
kill "$FB_PID" 2>/dev/null || true

step "сеть: админ входит в Firebase, и строгие правила пускают запись ивента"
FB_PORT2=$((8900 + $$ % 90))   # свой порт на каждый прогон: не липнем к занятому
rm -f /tmp/cb_fb_admin_dump.json /tmp/cb_fb_admin_auth.json
python3 tests/firebase_mock.py --port "$FB_PORT2" --require-auth \
    --dump /tmp/cb_fb_admin_dump.json --dump-auth /tmp/cb_fb_admin_auth.json \
    >/tmp/cb_fb_admin_mock.log 2>&1 &
FB_PID2=$!
sleep 1
CB_FB_API_KEY=test-key CB_AUTH_URL="http://127.0.0.1:$FB_PORT2/v1/accounts:signInWithPassword" \
  $BIN --frames 150 --fps 30 --realtime --scene 95 --profile "61=admin,62=Kenta2026" \
       --script tests/scripts/event_start.txt --fb-url "http://127.0.0.1:$FB_PORT2/" \
       --verbose >/tmp/cb_fb_admin.log 2>&1
check $?
grep -q "firebase: вход админа выполнен" /tmp/cb_fb_admin.log
check $?
# токен действительно ушёл в базу, а запись ивента прошла при --require-auth
python3 - <<'PYAUTH'
import json, sys
seen = json.load(open("/tmp/cb_fb_admin_auth.json"))
sys.exit(0 if "test-id-token" in seen else 1)
PYAUTH
check $?
python3 tests/fb_check_write.py /tmp/cb_fb_admin_dump.json "world/Ивент" 2
check $?
kill "$FB_PID2" 2>/dev/null || true

step "интро боя: в начале битвы идёт видео нужного кубика"
$BIN --scene 26 --frames 100 --fps 30 --size 1500x720 --profile "3=100,4=6,12=1,47=4" \
     --seed 11 --verbose >/tmp/cb_intro_1.log 2>&1
check $?
grep -q "видео: ролик 2 «Обычный кубик»" /tmp/cb_intro_1.log
check $?
$BIN --scene 26 --frames 100 --fps 30 --size 1500x720 --profile "3=100,4=6,12=1,47=4" \
     --seed 13 --verbose >/tmp/cb_intro_2.log 2>&1
check $?
grep -q "видео: ролик 3 «Настя кубик»" /tmp/cb_intro_2.log
check $?

step "интро боя: во время видео джойстик и способности выключены"
$BIN --scene 26 --frames 130 --fps 30 --size 1500x720 --profile "3=100,4=6,12=1,47=4" \
     --seed 11 --script tests/scripts/intro_lock.txt --trace 21 --trace 24 \
     >/tmp/cb_intro_lock.log 2>&1
check $?
python3 - <<'PY'
import re, sys

hero, joy = {}, {}
for line in open("/tmp/cb_intro_lock.log"):
    m = re.match(r"trace\s+(\d+).*id=(\d+)\s+x=\s*(-?[\d.]+).*vis=(\d)", line)
    if not m:
        continue
    frame, oid = int(m.group(1)), int(m.group(2))
    x, vis = float(m.group(3)), int(m.group(4))
    (hero if oid == 21 else joy)[frame] = (x, vis)

problems = []
# во время ролика (первые ~3 секунды) джойстик скрыт и игрок не двигается
for frame in (0, 30, 60, 90):
    if joy.get(frame, (0, 1))[1] != 0:
        problems.append(f"джойстик виден во время интро (кадр {frame})")
    if abs(hero.get(frame, (0, 0))[0]) > 1.0:
        problems.append(f"игрок поехал во время интро (кадр {frame})")
# после интро джойстик появляется и игрок слушается
if joy.get(110, (0, 0))[1] != 1:
    problems.append("джойстик не появился после интро")
if hero.get(120, (0, 0))[0] <= 20.0:
    problems.append("игрок не двигается после интро")
for p in problems:
    print(p)
sys.exit(1 if problems else 0)
PY
check $?

step "сцены 101/104/105/106: скрипты загружаются (номер сцены в каталоге)"
for id in 101 104 105 106; do
  $BIN --frames 6 --scene "$id" --verbose >/tmp/cb_scene_$id.log 2>&1
  check $?
  if grep -q "нет index.lua" /tmp/cb_scene_$id.log; then
    printf '   ПРОВАЛ: сцена %s без скриптов\n' "$id"
    FAILED=$((FAILED + 1))
  else
    printf '   OK сцена %s\n' "$id"
  fi
done

step "подарок: три тапа — открывается, выдаёт леденцы и возвращает в магазин"
$BIN --frames 175 --scene 104 --profile "80=44" --seed 11 \
     --script tests/scripts/egg_pop.txt --verbose >/tmp/cb_egg.log 2>&1
check $?
grep -q "toast: Вам выпало... 1 Леденец!" /tmp/cb_egg.log
check $?
# награда дошла до счётчика: в меню 44 + 1
grep -q 'var:80 .*значение="45"' /tmp/cb_egg.log
check $?

step "уведомление: тост снизу — тёмная скруглённая плашка с белым текстом"
$BIN --frames 70 --scene 104 --profile "80=44" --seed 11 \
     --script tests/scripts/egg_pop.txt --out /tmp/cb_frames_toast >/tmp/cb_toast.log 2>&1
check $?
python3 tests/check_shot.py toast /tmp/cb_frames_toast/frame_0064.png
check $?

step "поля ввода: белая подложка, как в Pocket Code"
$BIN --frames 8 --scene 31 --profile "24=100" --out /tmp/cb_frames_field >/dev/null 2>&1
check $?
python3 tests/check_shot.py field /tmp/cb_frames_field/frame_0007.png 300 -100
check $?
$BIN --frames 8 --scene 95 --out /tmp/cb_frames_ask >/dev/null 2>&1
check $?
# поле модального вопроса — тоже белое (точка левее каретки по центру)
python3 tests/check_shot.py field /tmp/cb_frames_ask/frame_0007.png -220 20
check $?

step "регистрация: как в старой версии — после заставки «Имя» и «Пароль»"
$BIN --frames 220 --out /tmp/cb_frames_reg --verbose >/tmp/cb_reg.log 2>&1
check $?
grep -q "сцена 77 Регистрация" /tmp/cb_reg.log
check $?
grep -q "Имя .*placeholder=\"Имя\"" /tmp/cb_reg.log
check $?
grep -q "Пароль .*placeholder=\"Пароль\"" /tmp/cb_reg.log
check $?
# поля белые: точка левее середины, чтобы не попасть в подсказку и каретку
python3 tests/check_shot.py field /tmp/cb_frames_reg/frame_0219.png -150 50
check $?
python3 tests/check_shot.py field /tmp/cb_frames_reg/frame_0219.png -150 -40
check $?

step "регистрация: ник и пароль видны чёрным на белом и сбрасываются при перезаходе"
rm -f /tmp/cb_acc.tsv
CB_STORE=/tmp/cb_acc.tsv $BIN --frames 90 --scene 77 --script tests/scripts/type_account.txt \
    --out /tmp/cb_frames_typing --verbose >/tmp/cb_typing.log 2>&1
check $?
grep -q "ввод подтверждён: Имя = \[admin\]" /tmp/cb_typing.log
check $?
grep -q "ввод подтверждён: Пароль = \[Kenta2026\]" /tmp/cb_typing.log
check $?
# текст в полях чёрный (раньше был прозрачным — набранное не было видно)
python3 tests/check_shot.py darktext /tmp/cb_frames_typing/frame_0089.png 0 50
check $?
python3 tests/check_shot.py darktext /tmp/cb_frames_typing/frame_0089.png 0 -40
check $?
# вход нигде не сохраняется: в локальном сторе нет строк account:
if [ -f /tmp/cb_acc.tsv ]; then
  ! grep -q "account:" /tmp/cb_acc.tsv
  check $?
fi
# заново открыли «Регистрацию» — поля пустые (только серая подсказка)
printf 'account:61\tadmin\naccount:62\tKenta2026\n' >/tmp/cb_acc_old.tsv
CB_STORE=/tmp/cb_acc_old.tsv $BIN --frames 110 --scene 77 --script tests/scripts/account_reenter.txt \
    --out /tmp/cb_frames_reenter >/tmp/cb_reenter.log 2>&1
check $?
python3 tests/check_shot.py emptyfield /tmp/cb_frames_reenter/frame_0109.png 0 50
check $?
python3 tests/check_shot.py emptyfield /tmp/cb_frames_reenter/frame_0109.png 0 -40
check $?

step "Дед Мороз: выпавший куб засчитывается и не теряется после перезапуска"
rm -f /tmp/cb_egg.tsv
CB_STORE=/tmp/cb_egg.tsv $BIN --frames 220 --fps 30 --scene 104 --seed 3 \
    --script tests/scripts/egg_open.txt --verbose >/tmp/cb_egg.log 2>&1
check $?
grep -q "Вам выпал... Снежный кубик!" /tmp/cb_egg.log
check $?
# куб сразу пишется в сохранение (раньше нужен был ручной «Сохранить прогресс»)
grep -q "WinterClass" /tmp/cb_egg.tsv
check $?
# второй запуск: класс уже открыт и его можно взять
CB_STORE=/tmp/cb_egg.tsv $BIN --frames 60 --fps 30 --scene 80 \
    --script tests/scripts/pashalnik_tap.txt --verbose >/tmp/cb_pash.log 2>&1
check $?
grep -q 'Класс "снежного кубика" экипирован' /tmp/cb_pash.log
check $?

step "ивент: админ запускает ивент 2 — он появляется на экране"
$BIN --frames 100 --scene 95 --profile "61=admin,62=Kenta2026" \
     --script tests/scripts/event_start.txt --verbose >/tmp/cb_event.log 2>&1
check $?
grep -q "ответ: Введите номер ивента = \[2\]" /tmp/cb_event.log
check $?
grep -q "0884_kolonki.png" /tmp/cb_event.log
check $?

step "ивент: без аккаунта админа админ-панель не включается"
$BIN --frames 60 --scene 95 --profile "61=Гость,62=123" \
     --script tests/scripts/admin_denied.txt --verbose >/tmp/cb_admin_denied.log 2>&1
check $?
grep -q "Нужен аккаунт админа" /tmp/cb_admin_denied.log
check $?
if grep -q "ответ: Введите номер ивента" /tmp/cb_admin_denied.log; then
  printf '   ПРОВАЛ: без админа можно запускать ивенты\n'
  FAILED=$((FAILED + 1))
else
  printf '   OK ивент без админа не запускается\n'
fi

step "ввод: текст без Enter подтверждается кнопкой «Ввести»"
rm -f /tmp/cb_promo.tsv
CB_STORE=/tmp/cb_promo.tsv $BIN --frames 40 --scene 31 --profile "24=100" \
     --script tests/scripts/promo_no_enter.txt --verbose >/tmp/cb_promo_noenter.log 2>&1
check $?
grep -q "ввод подтверждён: Промокод = \[MurderOfLove\]" /tmp/cb_promo_noenter.log
check $?
grep -q 'var:24 .*значение="145"' /tmp/cb_promo_noenter.log
check $?
# промокод одноразовый, как в оригинале: второй раз изумрудов не даёт
CB_STORE=/tmp/cb_promo.tsv $BIN --frames 40 --scene 31 --profile "24=100" \
     --script tests/scripts/promo_no_enter.txt --verbose >/tmp/cb_promo_twice.log 2>&1
check $?
grep -q 'var:24 .*значение="100"' /tmp/cb_promo_twice.log
check $?

step "ввод: диалог спрашивает по-настоящему — «Принять» отвечает, «Отмена» нет"
$BIN --frames 40 --scene 95 --script tests/scripts/ask_confirm.txt --verbose \
     >/tmp/cb_ask_confirm.log 2>&1
check $?
grep -q 'ответ: Выберите игрока (1/3) = \[1\]' /tmp/cb_ask_confirm.log
check $?
$BIN --frames 40 --scene 95 --script tests/scripts/ask_cancel.txt --verbose \
     >/tmp/cb_ask_cancel.log 2>&1
check $?
grep -q 'вопрос отменён: Выберите игрока (1/3)' /tmp/cb_ask_cancel.log
check $?
if grep -q 'ответ: Выберите игрока (1/3)' /tmp/cb_ask_cancel.log; then
  printf '   ПРОВАЛ: «Отмена» всё равно записала ответ\n'
  FAILED=$((FAILED + 1))
else
  printf '   OK «Отмена» ничего не записывает\n'
fi

step "кубы: стрелки вверх/вниз листают список, сами остаются на месте"
$BIN --frames 30 --scene 27 --script tests/scripts/cube_scroll.txt \
     --out /tmp/cb_frames_cubes >/tmp/cb_cubes.log 2>&1
check $?
python3 tests/check_shot.py scrolled /tmp/cb_frames_cubes/frame_0002.png \
     /tmp/cb_frames_cubes/frame_0020.png
check $?

step "движок: кадры — валидные PNG нужного размера"
python3 - <<'PY'
import struct, sys, glob
ok = True
for path in glob.glob("/tmp/cb_frames_1/*.png")[:3]:
    data = open(path, "rb").read(33)
    if data[:8] != b"\x89PNG\r\n\x1a\n":
        ok = False
    w, h = struct.unpack(">II", data[16:24])
    if (w, h) != (1500, 720):
        ok = False
        print("неверный размер кадра:", path, w, h)
sys.exit(0 if ok else 1)
PY
check $?

printf '\n'
if [ "$FAILED" -eq 0 ]; then
  echo "все проверки пройдены"
else
  echo "провалов: $FAILED"
fi
exit $FAILED
