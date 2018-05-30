; @return args A object
; 
; Ex) -x 10 -y 20 foo -z "test" "bar baz"
;
;; x=10, y=20, z=test
;MsgBox % "x=" args.x " ,y=" args.y " ,z=" args.z
;; foo
;; test
;; bar baz
;Loop % args.unclassified.Length(){
;  MsgBox % args.unclassified[A_Index]
;}
;; foo=, 1=
;MsgBox % "foo=" args.foo " ,1=" args.1
parse_arguments(){
  MODE_OPTNAME  = 1
  MODE_OPTVALUE = 2

  args   := {}
  mode   := MODE_OPTNAME
  curkey := ""

  args.unclassified := []

  for idx, value in A_Args{
    if(mode==MODE_OPTNAME){
      if(InStr(value, "-", 1)){
        ; -key の解釈.
        mode   := MODE_OPTVALUE
        curkey := substr(value, 2)
        continue
      }
      ; key 無し引数.
      args.unclassified.push(value)
      continue
    }

    if(mode==MODE_OPTVALUE){
      if(InStr(value, "-", 1)){
        MsgBox % "Invalid Option '" value "'!"
        ExitApp
      }
      args[curkey] := value
      mode := MODE_OPTNAME
      continue
    }
  }

  Return args
}
