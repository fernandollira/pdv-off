unit model.sinc.down;

{$mode delphi}{$H+}

interface

uses
  Classes, SysUtils, ExtCtrls, model.request.http, clipbrd, dialogs,
  ems.conexao,  ems.utils, Graphics,
  jsons, crt, model.usuarios;

Type

{ TSincDownload }

TSincDownload = class(TThread)
 private
       TabelasValidada : boolean;
       FMsg : String;
      FErro : String;
      Fprocessando : boolean;
      FProtocolo : String;
      FResponse : TJSONObject;
      FTokenPDV : String;
      FHistorico : TStringList;
      FPanel : TPanel;
      Fmsg_erro : string;
      FErro_Processamento : boolean;
      _db : TConexao;
      FFalhou : boolean;
      _name : String;
      _Registros : integer;
      _tProcessado : integer;

      Procedure Processa(_tabela:string; _jsonValue : TJsonArray);
      Procedure Consulta_Api(var _ok : Boolean) ;
      function valida_table(_tabelaName:string; Criar : boolean = true):boolean;
      function CriaTabela(_tabelaName:String):Boolean;

      Procedure SendUpload(_upload : TJsonObject);
      Procedure PreparaUpload(_upload : TJsonObject);
      Procedure ProcessarUpdate(Return:TJsonObject);
      Procedure Concluir ;
      Procedure ValidaTabelas;
 protected
   procedure Execute; override;
   Procedure AtualizaLog ;
   Procedure ControleDown(Sender: TObject; const ContentLength, CurrentPos: Int64);
 public
   Constructor Create(CreateSuspended : boolean; value : TPanel; _tokenpdv:string);
   destructor Destroy; override;
 end;

implementation

{ TSincDownload }


procedure TSincDownload.Processa(_tabela: string; _jsonValue: TJsonArray);
var  i : integer;
    _remove : TConexao;
begin
   _tabela := trim(_tabela);

   FMsg:='Checando Itens:'+_tabela;
   Synchronize(AtualizaLog);
   if _tabela <> 'financeiro_caixa' then
      _db.ChecaItensArrayToSQl(_tabela,_jsonvalue);

   FMsg:='Inserindo Itens:'+_tabela;
   Synchronize(AtualizaLog);

   if _tabela <> 'financeiro_caixa' then
      _db.InsertArrayToSQl(_tabela,_jsonvalue);

   FMsg:='Atualizando Itens :'+_tabela;
   Synchronize(AtualizaLog);
   _db.updateSQlArray(_tabela,_jsonvalue, _tabela = 'financeiro_caixa');

   if (_tabela='parametros_venda') or  (_tabela='parametros_produto') or
      (_tabela='parametros_fiscal') or (_tabela='parametros_geral') or
      (_tabela='ems_pdv')
   then
      sessao.InicializaConfigPadrao;


   if _tabela = 'financeiro_caixa' then
   Begin
       for i := 0 to _jsonValue.Count-1 do
       Begin
             if trim(_jsonValue.Items[i].AsObject['status'].AsString) = 'F' then
             Begin
                 try
                    _remove := TConexao.Create;
                      with _remove.qryPost do
                      Begin
                          Close;
                          Sql.Clear;
                          Sql.Add('delete from financeiro_caixa where id = '+QuotedStr(_jsonValue.Items[i].AsObject['id'].AsString));
                          RegistraLogRequest('caixa: ' +sql.text);
                          ExecSQL;
                      end;
                 finally
                       FreeAndNil(_remove);
                 end;
             end;
       end;
   end;

   FMsg:='finalizado :'+_tabela;
   Synchronize(AtualizaLog);
end;


procedure TSincDownload.Consulta_Api(var _ok: Boolean);
var _api : TRequisicao;
  _aux : String;
begin
_ok := false;
try
    try
        _api := TRequisicao.Create;
        _api.Metodo:= 'post';
        _api.webservice:= getEMS_Webservice(mPDV);
        _api.AddHeader('token-pdv',UpperCase(FTokenPDV));
        _api.AddHeader('protocolo',FProtocolo);
        _api.rota:='hibrido';
        _api.endpoint:= 'download';
        //_api.fphttpclient.OnDataReceived:= ControleDown;
        _api.Execute;


        if not (_api.ResponseCode in [200..207]) then
        Begin
             FMsg:= _api.Return['msg'].AsString;
             RegistraLogRequest('Requisicao: '+_api.response);
             Synchronize(AtualizaLog);
             _ok := false;
        end
        else
        Begin
            FResponse.Clear;
            if _api.ResponseCode <> 204 then
                FResponse.Parse(_api.return.Stringify);

            //RegistraLogRequest('erro: '+_api.response);
           _ok := true;
        end;


except
  on e: exception do
  Begin
       RegistraLogRequest('Consulta_Api Function : '+e.message);
       RegistraLogRequest('URl : '+_api.webservice);
       RegistraLogRequest('endPoint : '+_api.endpoint);
       RegistraLogRequest('rota : '+_api.rota);
       RegistraLogRequest('response : '+_api.response);
  end;
end;

finally
    FreeAndNil(_api);
end;
end;



function TSincDownload.valida_table(_tabelaName: string; Criar : boolean = true):boolean;
var _tabela : TConexao;
begin
try
  try
      _tabela := TConexao.Create;
      with _tabela.qrySelect do
      Begin
         Close;
         Sql.Clear;
         Sql.Add('select name from sqlite_master where type = '+QuotedStr('table'));
         Sql.Add(' and name  = '+QuotedStr(_tabelaName));
         open;

         if IsEmpty then
         Begin
               if Criar then
                  Result := CriaTabela(_tabelaName)
               else
                  Result := false;
         end
         else
            Result := true;
      end;
  finally
      FreeAndNil(_tabela)
  end;
except
     on e:exception do
     Begin
        RegistraLogRequest('Get Lista Tabela SqLite');
     end;
end;
end;

function TSincDownload.CriaTabela(_tabelaName: String): Boolean;
var _Api : TRequisicao;
begin
try
  Result := false;
  try

    _api := TRequisicao.Create;
    _api.Metodo:= 'get';
    _Api.AddHeader('table-name',_tabelaName);
    _Api.AddHeader('canal-token',canal_token);
    _api.webservice:= getEMS_Webservice(mAutenticacao);
    _Api.AutUserName:= Sessao.usuario;
    _Api.AutUserPass:= Sessao.senha;
    _api.rota:='autenticacao/table';
    _api.endpoint:='estrutura';
    _api.Execute;

    if _api.ResponseCode in [200..207] then
       _db.CreateTabela(_tabelaName,
                        _api.Return['resultado'].AsArray
                        );


  finally
      FreeAndNil(_api);
  end;
except
     on e:exception do
     Begin
           RegistraLogRequest('Criar Tabela '+_tabelaName+' ' +e.message);
           RegistraLogRequest('empresa: '  +_db.qrySelect.SQL.Text );
     end;
end;
end;

procedure TSincDownload.SendUpload(_upload : TJsonObject);
var _api : TRequisicao;
begin
  try
    try
        _api := TRequisicao.Create;
         _api.Metodo:= 'post';
         _api.Body.Text:= _upload.Stringify;
         _api.webservice:= getEMS_Webservice(mPDV);
         _api.AddHeader('token-pdv',FTokenPDV);
         _api.rota:='hibrido';
         _api.endpoint:= 'upload';

         FMsg:= 'Enviando Dados para Servidor';
         Synchronize(AtualizaLog());
         _api.Execute;

         if _api.ResponseCode in [200..207] then
         Begin
               ProcessarUpdate(_api.Return);
         end else
           FFalhou:= true;

    finally
       //  FreeAndnil(_api);
    end;
  except
       on e: exception do
       Begin
            RegistraLogRequest('Consulta_Api Function : '+e.message);
            RegistraLogRequest('URl : '+_api.webservice);
            RegistraLogRequest('endPoint : '+_api.endpoint);
            RegistraLogRequest('rota : '+_api.rota);
            RegistraLogRequest('response : '+_api.response);
            FMsg:= 'Falha Ao enviar Consulte log';
            FFalhou:= true;
            Synchronize(AtualizaLog);
       end;
  end;
end;

procedure TSincDownload.PreparaUpload(_upload: TJsonObject);
begin
    with _db.qrySelect do
    Begin
         _db.ChecaEstrutura('financeiro_caixa');
         Close;
         Sql.Clear;
         Sql.Add('select * from financeiro_caixa ');
         Sql.Add(' where (trim(sinc_pendente) = ''S'' or sinc_pendente is null) ');
         open;

         if not IsEmpty then
            _upload['itens'].AsObject.Put('financeiro_caixa',_db.ToArrayString);


         Close;
         Sql.Clear;
         Sql.Add('select * from venda ');
         Sql.Add(' where (trim(sinc_pendente) = ''S'' or sinc_pendente is null) ');
         open;

         if not IsEmpty then
            _upload['itens'].AsObject.Put('venda',_db.ToArrayString);

         Close;
         Sql.Clear;
         Sql.Add('select * from venda_itens ');
         Sql.Add(' where (trim(sinc_pendente) = ''S'' or sinc_pendente is null) ');
         open;

         if not IsEmpty then
            _upload['itens'].AsObject.Put('venda_itens',_db.ToArrayString);
    end;
end;

procedure TSincDownload.ProcessarUpdate(Return: TJsonObject);
var i : Integer;
   _name : String;
   _return : TJsonObject;
begin
   FMsg:= 'Iniciando Confirmação de Updates';
   Synchronize(AtualizaLog);

   _return := return['resultado'].AsObject;

   for i:= 0 to _return['itens'].AsObject.Count-1 do
   Begin
      _name := _return['itens'].AsObject.Items[i].Name;
      FMsg:= _name;
      Synchronize(AtualizaLog);

      _db.ProcessaSinc(_name, _return['itens'].AsObject[_name].AsArray);
   end;

end;

procedure TSincDownload.Concluir;
var _api : TRequisicao;
    _aux : String;
begin
try
     try
        _api := TRequisicao.Create;
        _api.Metodo:= 'post';
        _api.webservice:= getEMS_Webservice(mPDV);
        _api.AddHeader('protocolo',FProtocolo);
        _api.rota:='hibrido';
        _api.endpoint:= 'confirmadownload';
        _api.Execute;

        if not (_api.ResponseCode in [200..207]) then
        Begin
           FMsg:= _api.Return['msg'].AsString;
           FProtocolo:= '';
           Synchronize(AtualizaLog);
        end
        else
        Begin
            FResponse.Clear;
            FResponse.Parse(_api.return.Stringify);
        end;
     finally
           FreeAndNil(_api);
     end;

except
     on e: exception do
     Begin
          RegistraLogRequest('Consulta_Api Function : '+e.message);
          RegistraLogRequest('URl : '+_api.webservice);
          RegistraLogRequest('endPoint : '+_api.endpoint);
          RegistraLogRequest('rota : '+_api.rota);
          RegistraLogRequest('response : '+_api.response);
     end;
end;
end;

procedure TSincDownload.ValidaTabelas;
var _lista : TJsonObject;
    i : integer;
    _api : TRequisicao;
    _item : TJsonObject;
begin
    try
       try
           _api := TRequisicao.Create;
           _api.Metodo:= 'get';
           _Api.AddHeader('canal-token',canal_token);
           _api.webservice:= getEMS_Webservice(mAutenticacao);
           _Api.AutUserName:= Sessao.usuario;
           _Api.AutUserPass:= Sessao.senha;

           _api.rota:='autenticacao/table';
           _api.endpoint:='ddl';
           _api.Execute;

           if _api.ResponseCode in[200..207] then
           Begin
                _lista := _api.Return['resultado'].AsObject;
                for i := 0 to _lista['tabelas'].AsArray.Count-1 do
                Begin
                   _item := _lista['tabelas'].AsArray.Items[i].AsObject;

                   if valida_table(_item['item'].AsString,false) then
                      _db.ChecaDDL(_item['item'].AsString,
                                   _item['ddl'].AsArray
                                  )
                   else
                      _db.CreateTabela(_item['item'].AsString,
                                       _item['ddl'].AsArray
                                       );
                end;
                TabelasValidada := true;

                // Checando Sinc_DB e UUID
                _db.ChecaEstrutura('venda_itens');
                _db.ChecaEstrutura('vendas');
                _db.ChecaEstrutura('financeiro');
                _db.ChecaEstrutura('financeiro_caixa');

           end else
            RegistraLogRequest('Erro:' +_api.response);
       finally
           FreeAndNil(_api);
       end;
    except

    end;
end;


procedure TSincDownload.Execute;
var
   _itensJson : TJsonObject;
    j,i : Integer;
    _ok, _finalizado : Boolean;
    _time : integer;
begin

  while Fprocessando do
  Begin
      try
            if not TabelasValidada then
                ValidaTabelas;

            FMsg:= 'Conectando ao Servidor';
            Synchronize(AtualizaLog);
            Consulta_Api(_ok);

            FProtocolo:= FResponse['resultado'].AsObject['protocolo'].AsString;
            _finalizado:= FResponse['resultado'].AsObject['finalizado'].AsBoolean;

            FResponse['resultado'].AsObject.Delete('protocolo');
            FResponse['resultado'].AsObject.Delete('finalizado');
            FResponse['resultado'].AsObject.Delete('registros');

           if (_ok) and (FResponse.Stringify <> '{}') then
           Begin

               _itensJson := FResponse['resultado'].AsObject;
               FErro_Processamento:= false;

               _Registros := 0;
               _tProcessado := 0;
               for I := 0 to _itensJson.Count - 1 do
               Begin
                   _name := _itensJson.Items[i].Name;
                   _Registros := _Registros + _itensJson[_name].AsArray.count;
               end;


               for I := 0 to _itensJson.Count - 1 do
               begin
                   _name := _itensJson.Items[i].Name ;

                   _tProcessado := _tProcessado + _itensJson[_name].AsArray.Count;

                   FMsg:= _name + ' Registros: '+IntToStr(_Registros)+'/'+IntToStr(_tProcessado);
                   Synchronize(AtualizaLog);

                   if valida_table(_name) then
                   Begin
                       Processa(_name,
                               _itensJson[_name].AsArray
                               );
                   end
                   else
                   Begin
                       FErro_Processamento:= true;
                       RegistraLogRequest('Tabela inexistente '+ _name);
                   end;
               end;

               Fprocessando:= false;

           end;


           if (i >= 0 ) and (_ok) then
           Begin
               if FResponse.Stringify <> '{}' then
               Begin
                  if NOT Fprocessando then
                  Begin
                      if (not FErro_Processamento) and (_itensJson.Count> 0) then
                      Begin
                           if _finalizado then
                              Concluir;
                      end;

                      FFalhou:= FErro_Processamento;
                  end;
               end;
               Synchronize(AtualizaLog);
           end
           else
              Fprocessando:= false;

           if _finalizado = true then
           Begin
               _time := 5000 ;
               FProtocolo := '';
           end
           else
             _time := 0;


            if (Sessao.segundoplano) then
            Begin
                 _itensJson := TJsonObject.Create();
                 PreparaUpload(_itensJson);

                 if _itensJson['itens'].AsObject.Count > 0 then
                    SendUpload(_itensJson);
                 FreeAndNil(_itensJson);

                 FMsg:= 'Ultima Sicronização '+ FormatDateTime('dd/mm/yyyy hh:mm:ss',now);
                 Synchronize(AtualizaLog);
                 Fprocessando:= true;
                 Delay(_time);
            end else
            Begin
                FMsg:= 'Etapa: '+ FResponse['etapa'].AsString +
                       ' > Registros : '+ FResponse['registro'].AsString;

                Synchronize(AtualizaLog);
                Delay(2000);

                Fprocessando:= not _finalizado;
            end;

            FResponse.Clear;
      except
          on e:exception do
          Begin
              RegistraLogErro(e.message);
              Fprocessando:= not _finalizado;
              FMsg:= 'Erro ao Processar';

              Synchronize(AtualizaLog);
              FProtocolo:= '';
              Delay(1000);
          end;
      end;
  end;
end;

procedure TSincDownload.AtualizaLog;
begin

  FPanel.Caption:= FMsg+'  ';
  FPanel.Repaint;
  fpanel.enabled := true;

  if FFalhou then
     FPanel.Font.Color := clred
  else
    FPanel.Font.Color := clwhite;

  if not FPanel.Visible then
     FPanel.Visible:= true;

  if FErro <> '' then
  Begin
     FHistorico.Add(ferro);
     //RegistraLogRequest(FHistorico.Text);
     FErro:= '';
  end;

  FFalhou:= false;
end;

procedure TSincDownload.ControleDown(Sender: TObject; const ContentLength,
  CurrentPos: Int64);
begin
      Fmsg:='Fazendo Download ' +InttoStr(SizeOf(ContentLength))+'/'+
              InttoStr(SizeOf(CurrentPos)) ;
      Synchronize(AtualizaLog);
end;

constructor TSincDownload.Create(CreateSuspended: boolean; value: TPanel; _tokenpdv:string);
begin
  FFalhou:= false;
  FHistorico := TStringList.Create;
  FProcessando := true;
  FProtocolo:= '';
  FPanel := value;
  FTokenPDV := _tokenpdv;
  FreeOnTerminate := true;

  FResponse := TJsonObject.Create;

  _db := TConexao.Create;

  TabelasValidada:= false;

  inherited Create(CreateSuspended);
end;

destructor TSincDownload.Destroy;
begin
  FMsg:= 'Sincronismo encerrado';
  Synchronize(AtualizaLog);
  FreeAndNil(FResponse);
  FreeAndNIl(FHistorico);
  FreeAndNIl(_db);
  inherited Destroy;
end;

end.

