
prepare:

; config
SetWorkingDir %A_ScriptDir%
CoordMode Menu, Screen
CoordMode Mouse, Screen

; consts
BASEDIR = %A_ScriptDir%
SP = \
EMBED_COUNTER_DELIM  := " | "
EMPTY_STRING_DISPLAY := "<Empty>"
SYSCMD_PARENT_DIR    := 1

; includes
#Include %A_ScriptDir%\libargument.ahk
#Include %A_ScriptDir%\config.ahk

; parsing_commandline_arguments
args := parse_arguments()

main:

list_fullpath := Object()
menuname_root := "menuname_root"
search_dir := determin_search_dir_root(args)
counter := new Counter()
;ahk は 1-origin なので +1
counter.plus() 

try {
  Menu, %menuname_root%, DeleteAll
} catch e {
  ; 初回時はメニューが存在せずしくじるので吸収する.
}

; prepend system command.
counter.plus()
list_fullpath.Push("DUMMY DATA")
Menu, %menuname_root%, Add, <<Parent Directory(&\)>> %EMBED_COUNTER_DELIM% 1, label_open

; prepare data for folder exclusion
exclude_folderlist := create_exclude_folderlist()

parse(menuname_root, list_fullpath, counter, search_dir)

posobj := determin_showpos(args)
showx := posobj.x
showy := posobj.y
Menu, %menuname_root%, Show, %showx%, %showy%
Return

label_open:
selected_idx := get_menuitem_index_from_menuname(A_ThisMenuItem, EMBED_COUNTER_DELIM)
; goto が関数内から使えないので, 汚いがここに書く...
if(selected_idx==SYSCMD_PARENT_DIR){
  SplitPath, search_dir, , parent_of_search_dir
  ; 辿る先は determin_search_dir_root() で決めているので
  ; これに沿うようなやり方(argsを直接いじる)で更新する.
  args.unclassified[1] := parent_of_search_dir
  goto, main
}
selected_fullpath := list_fullpath[selected_idx]
open_method(selected_fullpath)
Return

funcs:
Return

open_method(fullpath){
  s := GetKeyState("Shift")
  a := GetKeyState("Alt")
  c := GetKeyState("Control")
  w := GetKeyState("LWin")

  if(s && !a && !c && !w){
    editor_path := CONFIG.TEXT_EDITOR_PATH
    Run, "%editor_path%" "%fullpath%"
    Return
  }
  if(!s && !a && c && !w){
    SplitPath, fullpath, , dirname
    Run, %dirname%
    Return
  }
  ; open normally.
  Run, %fullpath%
}

; @param args A object parse_arguments() returns.
determin_showpos(args){
  ; デフォはマウス座標で, 他に指定があればそっちを使う感じに.
  pos := get_mouse_pos()

  if(is_not_empty_argument(args.x)){
    pos.x := args.x
  }
  if(is_not_empty_argument(args.y)){
    pos.y := args.y
  }

  Return pos
}

; @param args A object parse_arguments() returns.
determin_search_dir_root(args){
  if(args.unclassified.Length() == 0){
    Return %A_WorkingDir%
  }
  Return args.unclassified[1]
}

; Config の ".git;node_modules;..."
; ↓
; Array [".git", "node_modules", ...] ← これを作る.
;
; parse 関数内から使うなら Array しか手段が無い.
; Q1: parse 関数内で split するのは？
;     → 処理時間かかるのでダメ(先に計算しておきたい)
; Q2: split 後の var1 var2 ... varN 形式を使うのは？
;     → global var1, global var2, ... しか使えないのでダメ.
create_exclude_folderlist(){
  config_exclude_foldername := CONFIG.EXCLUDE_FOLDERNAME
  StringSplit, exclude_folders, config_exclude_foldername, ";"

  exclude_folderlist := Object()

  Loop, %exclude_folders0%
  {
    excluder_name = exclude_folders%A_Index%
    exclude_folderlist.Insert(%excluder_name%)
  }

  Return exclude_folderlist
}

; @param menuname A string
; @param list_fullpath A object
; @param counter A Counter instance for each item id.
; @param search_dir A string absolute directory path
parse(menuname, list_fullpath, counter, search_dir){
  ; グローバルな定数にアクセスするのにいちいち global するのだるいな...
  global EMBED_COUNTER_DELIM
  global EMPTY_STRING_DISPLAY
  ; exclude_folderlist は中身が変化しないので global で先に計算したものを使うように.
  global exclude_folderlist

  ; この search_dir が持つファイル(フォルダ含む)数.
  ; これが 0 の場合にそのままスルーするとサブメニュー結合時にこけちゃうので
  ; 対処している.
  filecount := 0

  Loop, Files, %search_dir%\*, F
  {
    fullpath := BASEDIR SP A_LoopFileFullPath
    filename := A_LoopFileName
    dirname  := A_LoopFileDir

    itemname := A_LoopFileName
    curcount := counter.get()

    list_fullpath.Push(fullpath)
    ; label_open 側で選択項目を一意に特定する術がないため,
    ; カウンタ情報を付けておく.
    Menu, %menuname%, Add, %itemname%%EMBED_COUNTER_DELIM%%curcount%, label_open

    counter.plus()
    filecount := filecount + 1
  }

  Loop, Files, %search_dir%\*, D
  {
    fullpath := BASEDIR SP A_LoopFileFullPath
    filename := A_LoopFileName
    dirname  := A_LoopFileDir

    itemname := A_LoopFileName

    ; フォルダ除外
    should_this_folder_skip := false
    For index,exclude_foldername in exclude_folderlist
    {
      if(itemname == exclude_foldername){
        should_this_folder_skip := true
        Continue
    }
    }
    if(should_this_folder_skip){
      Continue
    }

    ; メニュー名が重複するとサブメニューを一意に作れないので
    ; 重複しないであろうフルパスを使うことにする.
    ; 加えて, メニュー名に記号類は含められないので省く.
    new_menuname := StrReplace(fullpath, "\")
    new_menuname := StrReplace(new_menuname, ":")
    new_menuname := StrReplace(new_menuname, ".")
    new_menuname := StrReplace(new_menuname, " ")

    new_search_dir := search_dir "\" itemname

    parse(new_menuname, list_fullpath, counter, new_search_dir)
    Menu, %menuname%, Add, %itemname%, :%new_menuname%

    filecount := filecount + 1
  }

  if(filecount == 0){
    Menu, %menuname%, Add, %EMPTY_STRING_DISPLAY%, label_open
    Menu, %menuname%, Disable, %EMPTY_STRING_DISPLAY%
    Return
  }

}

get_mouse_pos(){
  MouseGetPos, mousex, mousey

  mousepos := {}
  mousepos.x := mousex
  mousepos.y := mousey
  Return mousepos
}

get_menuitem_index_from_menuname(menuname, delim){
  ls := StrSplit(menuname, delim)
  Return ls[2]
}

is_empty_argument(arg){
  Return arg==""
}

is_not_empty_argument(arg){
  Return arg!=""
}

classes:
Return

class Counter {
  __New(){
    this._v := 0
  }

  plus(){
    curv := this._v
    newv := curv + 1
    this._v := newv
  }

  get(){
    Return this._v
  }
}
