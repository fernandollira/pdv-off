unit controller.condicional;

{$mode delphi}

interface

uses
  Classes, SysUtils, BufDataset, db, jsons, model.request.http,
   Dialogs,crt,wcursos;

type

{ TCondicional }

TCondicional = Class
  private
    fcliente_id: integer;
    fconclusao: TDateTime;
    femissao: TDateTime;
    fempresa_id: integer;
    fid: Integer;
    fnome: string;
    foperador_id: integer;
    fstatus: string;
    fvendedor_id: integer;
    procedure carrega(value:TJsonObject);

  public
      property id : Integer read fid write fid;
      property nome : string read fnome write fnome;
      property status : string read fstatus write fstatus;
      property empresa_id: integer read fempresa_id write fempresa_id;
      property vendedor_id : integer read fvendedor_id write fvendedor_id;
      property cliente_id : integer read fcliente_id write fcliente_id;
      property operador_id : integer read foperador_id write foperador_id;

      property emissao : TDateTime read femissao write femissao;
      property conclusao : TDateTime read fconclusao write fconclusao;

      Procedure Filtrar(_query : TDataSet;  _status,_empresa,_emissaoInicial, emissaoFinal,
                        _conclusaoInicial, _conclusaoFinal: string);

      function Iniciar : boolean;
      Procedure editar;
      function estorna(_itemID:Integer) : Boolean;
end;



implementation

uses classe.utils, view.condicional;


{ TCondicional }

procedure TCondicional.carrega(value: TJsonObject);
begin
  self.id := value['id'].AsInteger;
  _saveDebug(value.Stringify, 'condicional');
  self.emissao:= GetData(value['data_emissao'].AsString);
end;

procedure TCondicional.Filtrar(_query: TDataSet; _status,_empresa,_emissaoInicial, emissaoFinal,
  _conclusaoInicial, _conclusaoFinal: string);
var _body : TJsonObject;
  _Api : TRequisicao;
begin
 try
   WCursor.SetWait;

   _body := TJsonObject.Create;
   _Api := TRequisicao.Create;
   _body.Put('nome_cliente', self.nome);

   with _body['status'].AsArray do
       Put(_status);

   with _body['empresa'].AsArray do
       Put(_empresa);

   if _emissaoInicial <> ''then
      _body.Put('emissao_inicial',FormatDateTime('yyyy-mm-dd', StrToDate(_emissaoInicial)));

   if emissaoFinal <> ''then
      _body.Put('emissao_final',FormatDateTime('yyyy-mm-dd', StrToDate(emissaoFinal)));

   if _conclusaoInicial <> ''then
      _body.Put('conclusao_inicial',FormatDateTime('yyyy-mm-dd', StrToDate(_conclusaoInicial)));

   if _conclusaoFinal <> ''then
      _body.Put('conclusao_final',FormatDateTime('yyyy-mm-dd', StrToDate(_conclusaoFinal)));

   if _query.Active then
      ClearAllRecords(_query);

   with _Api do
   Begin
       Metodo:='post';
       Body.Text:= _body.Stringify;
       tokenBearer := GetBearerEMS;
       webservice := getEMS_Webservice(mCondicional);
       rota:='condicional';
       endpoint:='listar';

       Execute;

       if ResponseCode in [200..207] then
          JsonToDataSet(_query)
       else
          Showmessage('#150 Contate suporte: '+_Api.response);
   end;

 finally
   FreeAndNil(_body);
   FreeAndNil(_Api);
   WCursor.SetNormal;
 end;

end;

function TCondicional.Iniciar: boolean;
var _api : TRequisicao;
   _body : TjsonObject;
begin
  try
    _api := TRequisicao.Create;
    _body := TJsonObject.Create;
    _body['empresa_id'].AsInteger:= Self.empresa_id;
    _body['vendedor_id'].AsInteger:= Self.vendedor_id;
    _body['cliente_id'].AsInteger:= Self.cliente_id;
    _body['operador_id'].AsInteger:= Self.operador_id;
    _body['tabela_preco_id'].AsInteger:= Sessao.tabela_preco_id;
    _body['estoque_id'].AsInteger:= Sessao.estoque_id;


    with _api do
    Begin
        Metodo:='post';
        Body.Text:= _body.Stringify;
        tokenBearer := GetBearerEMS;
        webservice := getEMS_Webservice(mCondicional);
        rota:='condicional';
        endpoint:='criar';
        Execute();

        Result := (_api.ResponseCode in [200..207]);

        if Result then
        Begin
              Carrega(_api.Return);
        end else
           Showmessage(_api.response);
    end;

  finally
    FreeAndNil(_api);
  end;
end;

procedure TCondicional.editar;
var _api : TRequisicao;
begin
  try
    WCursor.SetWait;
    _Api := TRequisicao.Create;
    with _api do
    Begin
        Metodo:='get';
        tokenBearer := GetBearerEMS;
        webservice := getEMS_Webservice(mCondicional);
        rota:='condicional';
        endpoint:='';
        getID := IntToStr(self.id);
        Execute();



        if (_api.ResponseCode in [200..207]) then
        Begin
              f_condicional := Tf_condicional.Create(nil);
              f_condicional.dadosJson.Assign(_api.Return['resultado'].AsObject);
              WCursor.SetNormal;
              f_condicional.ShowModal;
        end else
           Showmessage(_api.response);
    end;
  finally
     FreeAndNil(_api);
     WCursor.SetNormal;
  end;
end;

Function TCondicional.estorna(_itemID:Integer): Boolean;
var _api : TRequisicao;
begin
  try
    WCursor.SetWait;
    _Api := TRequisicao.Create;
    result := false;
    with _api do
    Begin
        Metodo:='delete';
        tokenBearer := GetBearerEMS;
        webservice := getEMS_Webservice(mCondicional);
        rota:='condicional';
        endpoint:=IntTostr(self.id)+'/item/'+IntTostr(_itemID);
        Execute();

        RegistraLogErro('delete '+ _api.response);

        result := ResponseCode in [200..207];

        if not Result  then
           Showmessage(_api.Return['msg'].AsString);
    end;
  finally
     WCursor.SetNormal;
  end;
end;


end.

