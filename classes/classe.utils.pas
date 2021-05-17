unit classe.utils;

{$mode delphi}{$H+}

interface

uses
  Classes, SysUtils, model.conexao, Dialogs, md5, process, Graphics,
  controls, StdCtrls, Forms, TypInfo, DateUtils, db, cluster_pdv.sessao,
  wcursos;

type
  TPathServicos = (mAutenticacao, mCondicional, mGeral, mPDV);


var Sessao : TSessao;
    //f_wait : TWaitProcess;
    WCursor : TWaitCursor;

  function md5Text(value:string):String;
  function bioswindows : String;
  procedure limpabase;
  Procedure setOnEnter(form:TForm);
  procedure OnEntrar(Sender: TObject);
  procedure OnSair(Sender: TObject);
  Function FlagBoolean(value:string):String;
  Procedure RegistraLogErro(value:string);


  Function getDataUTC : String;
  function prepara_valor(value: double): String;
  function FlagBool(value: Boolean): String;
  Function SubsString(text,old_value, new_value : string):String;
  function RemoveAcento( str: string): string;
  procedure _saveDebug(_text,_file:string);
  function getEMS_Webservice(value:TPathServicos): string;
  procedure ClearAllRecords(ADataset: TDataset);
  function GetBearerEMS:String;

  function GetData(value:string):TDateTime;


  function FormataCNPJ(CNPJ: string): string;
  function RemoveIfens(value: string): String;

implementation

uses model.request.http;

function RemoveIfens(value: string): String;
begin
   Result := SubsString(value,'-','');
   Result := SubsString(Result,'"','');
   Result := SubsString(Result,'.','');
   Result := SubsString(Result,',','');
   Result := SubsString(Result,'/','');
end;


function FormataCNPJ(CNPJ: string): string;
begin
  cnpj := RemoveIfens(cnpj);

  Result :=Copy(CNPJ,1,2)+'.'+Copy(CNPJ,3,3)+'.'+Copy(CNPJ,6,3)+'/'+

    Copy(CNPJ,9,4)+'-'+Copy(CNPJ,13,2);

end;

procedure ClearAllRecords(ADataset: TDataset);
begin
  ADataset.DisableControls;
  try
    ADataset.First;
    while not ADataset.EoF do
      ADataset.Delete;
  finally
    ADataset.EnableControls;
  end;
end;

function GetBearerEMS:String;
var _api : TRequisicao;
begin
   if sessao.bearerems= '' then
   Begin
       _api:= TRequisicao.Create;
       _api.webservice := getEMS_Webservice(mAutenticacao);
       _api.AutUserName := sessao.usuario;
       _api.AutUserPass := sessao.senha;
       _api.AddHeader('empresa-id',IntToStr(sessao.empresalogada));
       _api.AddHeader('canal-token','9b1b6b2dfcb8d4c13d4d7fcacd9aed78');
       _api.Metodo:= 'get';
       _api.rota := 'autenticacao';
       _api.endpoint := 'token/';
       _api.Execute();

       if _api.ResponseCode in [200..207] then
           sessao.bearerems:= _api.Return['token'].AsString;


   end;
   Result := sessao.bearerems;

end;

function GetData(value: string): TdateTime;
var
   aux : String;
begin

   aux := copy(value,9,2);
   aux := aux + '/'+copy(value,6,2)+'/';
   aux := aux + copy(value,1,4);
   aux := aux + copy(value,11,8);
   result := StrToDateTime(aux);
end;


procedure OnEntrar(Sender: TObject);
var
  Prop: PPropInfo;
begin
  Prop := GetPropInfo(Sender, 'Color');
  if (Assigned(Prop)) then
  begin
    SetPropValue(Sender, 'Color', clWindow);
  end;
end;

procedure OnSair(Sender: TObject);
var
  Prop: PPropInfo;
begin
  Prop := GetPropInfo(Sender, 'Color');
  if (Assigned(Prop)) then
  begin
    SetPropValue(Sender, 'Color', clGradientActiveCaption);
  end;
end;

function FlagBoolean(value: string): String;
begin
   result := trim(LowerCase(value));
end;

procedure RegistraLogErro(value: string);
var _text : TStringList;
    _diretorio : String;
begin
  try
     _text := TStringList.Create;
     _diretorio := extractfiledir(paramstr(0));// ExtractFileDir(ApplicationName);

     if FileExists(_diretorio+'/log.txt') then
        _text.LoadFromFile(_diretorio+'/log.txt');

     _text.Add(formatdatetime('dd-mm-yyyy hh:mm:ss',now)+' '+value);

     _text.SaveToFile(_diretorio+'/log.txt');
  finally
     FreeAndNil(_text);
  end;
end;

function getDataUTC: String;
begin
  Result := DateToISO8601(LocalTimeToUniversal(now));
end;

function prepara_valor(value: double): String;
var aux:string;
begin
       if value > 500000000 then
          value := 0
       else
          aux:=formatfloat('#0.0000000',(value));

       aux:=SubsString(aux,',','.');
       result:=aux;

       if result = '' then
          result := '0';


       if Length(result) > 17 then
          result := '0';
end;

function FlagBool(value: Boolean): String;
begin
 if value then
    result := 'true'
 else
    result := 'false';
end;

function SubsString(text, old_value, new_value: string): String;
begin
 Result:=  stringReplace(text , old_value, new_value ,[rfReplaceAll, rfIgnoreCase]);
end;

function RemoveAcento(str: string): string;
const
  AccentedChars :array[0..25] of string =
                 ('á','à','ã','â','ä','é','è','ê','ë','í','ì','ï','î',
                  'ó','ò','õ','ô','ö','ú','ù','ü','û','ç','ñ','ý','ÿ');
  NormalChars :array[0..25] of string =
                 ('a','a','a','a','a','e','e','e','e','i','i','i','i',
                  'o','o','o','o','o','u','u','u','u','c','n','y','y');
var
   i: Integer;
begin
   Result := str;
   for i := 0 to 25 do
      Result := StringReplace(Result, AccentedChars[i], NormalChars[i], [rfReplaceAll]);
end;

procedure _saveDebug(_text, _file: string);
var _save : TStringList;
begin
  try
     _save := TStringList.Create;
     _save.Text:=_text;
     _save.SaveToFile('/home/log_webservice/'+_file+'.txt');
  finally
     FreeAndNil(_save);
  end;
end;

function getEMS_Webservice(value:TPathServicos): string;
begin
    case value of
      mGeral :
         result := 'https://api-dev.clustererp.com.br/api/v1/';
      mCondicional :
         result := 'https://api-dev.clustererp.com.br/api/v1/';
      mAutenticacao :
         result := 'https://api-dev.clustererp.com.br/api/v1/';
      mPDV :
         result := 'https://api-dev.clustererp.com.br/api/v1/';
    end;

end;



function bioswindows : String;
var
  AProcess: TProcess;
  info : TStringList;
begin
 try
  AProcess := TProcess.Create(nil);
  info := TStringList.Create;
  AProcess.Executable := 'wmic';
  AProcess.Parameters.Add('bios');
  AProcess.Parameters.Add('get');
  AProcess.Parameters.Add('serialnumber');
  AProcess.Options := AProcess.Options + [poWaitOnExit, poUsePipes];
  AProcess.ShowWindow := swoHIDE;
  AProcess.Execute;
  info.LoadFromStream(AProcess.Output);
  Result := info.text;
  finally
     FreeAndNil(AProcess);
     FreeAndNil(info);
  end;
end;

procedure limpabase;
var _data : TConexao;
begin
   try
      _data := TConexao.Create;

      with _data.Query do
      begin
          Close;
          Sql.clear;
          Sql.add('delete from pdv');
          ExecSQL;
      end;
   finally
      FreeAndNil(_data);
   end;
end;

procedure setOnEnter(form: TForm);
var
   i:integer;
begin
{     for i:=0 to form.ComponentCount-1 do
     begin
          if (form.Components[i]).ClassType = TEdit then
          Begin
            if (form.Components[i] as TEdit).Tag = 0 then
            Begin
                (form.Components[i] as TEdit).OnEnter:= OnEntrar;
                (form.Components[i] as TEdit).OnExit:= @OnSair;
            end;
          end;
     end;  }
end;

function md5Text(value: string): String;
begin
   Result := MD5Print(MD5String(value));
end;




end.

