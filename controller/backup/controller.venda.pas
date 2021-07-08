unit controller.venda;

{$mode delphi}

interface

uses
  Classes, SysUtils, jsons, model.vendas.config, clipbrd;

       Function RegistraItemVenda(_codigo : String; _vendaUUID: string; quantidade : double ) : Boolean;
       procedure VendaGetItemRecalculo(var _dados : TJsonObject);
implementation

uses ems.conexao, ems.utils, model.vendas.imposto,
     view.filtros.produtos.selecao;

procedure VendaGetItemRecalculo(var _dados : TJsonObject);
begin
//      ValidaEdicao(_vendaID);

      defaultNumber(_dados,'aliq_desconto');
      defaultNumber(_dados,'aliq_outras_despesas');

      setDadosBasico(_dados);

      defaultInteger(_dados,'cfop',5102);

      defaultString(_dados,'lote_id');
      defaultString(_dados,'inflote');
      defaultString(_dados,'chave_nfe');
      defaultString(_dados,'drawback');
      defaultString(_dados,'reg_exportacao');
      defaultString(_dados,'num_fatura');

      defaultBoolean(_dados,'defaultvalue',true);
      defaultBoolean(_dados,'show_desconto',true);

      _dados['vl_frete'].AsNumber:= Decimal(GetValorAliquota(_dados['vl_produtos'].AsNumber,_dados['aliq_frete'].AsNumber));

      SetCenario(_dados);
      validandoBaseCalculo(_dados);
      validandoValorCalculo(_dados);

      if StrToFloatDef(_dados['tributavel_quantidade'].AsString,0) = 0 then
         _dados['tributavel_quantidade'].AsNumber:= DecimalQuantidade(_dados['quantidade'].AsNumber);

      if _dados['tributavel_unidade'].AsString = '' then
         _dados['tributavel_unidade'].AsString:= _dados['medida_descricao'].AsString;

      if (StrToFloatDef(_dados['tributavel_valor'].AsString,0) = 0) or
         (_dados['tributavel_unidade'].AsString = _dados['medida_descricao'].AsString)
      then
         _dados['tributavel_valor'].AsNumber:= DecimalUnitario(_dados['valor_final'].AsNumber);


      if _dados['tributavel_gtin'].AsString = '' then
         _dados['tributavel_gtin'].AsString:= _dados['gtin'].AsString;
end;

Function GetSqlProduto(_produtoID ,_armazenamentoID,  _precoID:string ; _gradeID:String =''):String;
var iSql : TStringList;
begin
  try
       iSql := TStringList.Create;

      with iSql do
      Begin
          Add('select p.id produto_id, ');
          Add('        case when pgri_1.descricao <> '''' and pgri_2.descricao <> '''' then ');
          Add('        p.descricao ||'' ''|| grd_1.descricao_resumida||'' ''||');
          Add('        pgri_1.descricao|| '' ''||grd_2.descricao_resumida||'' ''||pgri_2.descricao');
          Add('        when pgri_1.descricao <> ''''  then');
          Add('        p.descricao||'' ''||pgri_1.descricao');
          Add('        else');
          Add('        p.descricao end as descricao,');
          Add('       p.gtin, p.referencia, p.ativo, p.ncm_id ncm, p.origemmercadoria origem_mercadoria,');
          Add('       p.tipo_produto, p.cest, p.pesobruto, p.pesoliquido,');

          Add('       sg.descricao n_subgrupo,');
          Add('       pg.descricao n_grupo, pm.descricao n_marca,');

          Add('       pu.un medida_descricao, pc.descricao n_colecao, pu.id unidade_medida_id,');

          Add('       pgrd.gtin_grade,');
          Add('       pes.saldo_gerencial,');
          Add('       pa.descricao n_estoque,');
          Add('       ppv.valor, tp.descricao n_tabela,');
          Add('       ncm.descricao n_ncm,');
          Add('       pgrd.id gradeamento_id, ');

          Add(' ppc.custo_markup custo_unitario ');
          Add('from produtos p inner join produtos_empresa pe');
          Add('                      on pe.produto_id = p.id');

          Add('                      inner join produtos_estoque pes');
          Add('                      on pes.produto_empresa_id = pe.id');

          Add('                      inner join produtos_armazenamento pa');
          Add('                      on pa.id  = pes.produto_armazenamento_id');
          Add('                      and pa.id = '+QuotedStr(_armazenamentoID));
          Add('                      and pa.empresa_id = pe.empresa_id');

          Add('                      inner join produtos_preco_venda ppv');
          Add('                      on ppv.produto_empresa_id = pe.id');
          Add('                      and ppv.tabela_id = '+QuotedStr(_precoID));

          Add('                      left join produtos_preco_custo ppc');
          Add('                      on ppc.id = pe.preco_custo_id');

          Add('                      inner join tabela_preco tp');
          Add('                      on tp.id = ppv.tabela_id');

          Add('                      left join produtos_subgrupos sg');
          Add('                      on sg.id = p.subgrupo_id');

          Add('                      left join produtos_grupos pg');
          Add('                      on pg.id = sg.grupo_id');

          Add('                      left join produtos_marcas pm');
          Add('                      on pm.id = p.marca_id');

          Add('                      left join produtos_unidades pu');
          Add('                      on pu.id = p.unidade_id');

          Add('                      left join produtos_colecoes pc');
          Add('                      on pc.id = p.colecao_id');

          Add('                      left join lista_ncm ncm');
          Add('                      on ncm.ncm = p.ncm_id');

          Add('                      left join produtos_gradeamento pgrd');
          Add('                      on pgrd.produto_id  = p.id');

          Add('                      left join produtos_grades_itens pgri_1');
          Add('                      on pgri_1.id = pgrd.grade_item_id');

          Add('                      left join produtos_grades grd_1');
          Add('                      on grd_1.id = pgri_1.grade_id');

          Add('                      left join produtos_grades_itens pgri_2');
          Add('                      on pgri_2.id = pgrd.grade_item2_id');

          Add('                      left join produtos_grades grd_2');
          Add('                      on grd_2.id = pgri_2.grade_id');
          Add('where');
          Add('     1 = 1');

          Add('and ( ');


          if Length(_produtoID) < 6 then
             Add('p.id = '+QuotedStr(_produtoID)+' or ');

          Add(' p.gtin = '+QuotedStr(_produtoID)+
                  ' or pgrd.gtin ='+QuotedStr(_produtoID)+
                  ' or pgrd.gtin_grade = '+QuotedStr(_produtoID)+
                  ' )');

          if StrToIntDef(_gradeID,0) >0  then
             Add(' and pgrd.id = '+QuotedStr(_gradeID));


          Add('order by 2');

          Result := Text;

          RegistraLogErro(text);

          sessao.gradeID:= '';
      end;

  finally
      FreeAndNil(iSql);
  end;
end;

function RegistraItemVenda(_codigo: String; _vendaUUID: string; quantidade: double
  ): Boolean;
var _db  : TConexao;
    _tabelaPrecoID, _armazenamentoID : Integer;
    _gradeID : string;

    _Produto : TJsonObject;
begin
   Result := false;
   try
      _db := TConexao.Create;
      with _db.qrySelect do
      Begin
        Close;
        Sql.Clear;
        Sql.Add('select');
        Sql.Add('COALESCE(v.tabela_preco_id,0) AS tabela_preco_id,');
        Sql.Add('COALESCE(v.armazenamento_id,0) AS armazenamento_id');
        Sql.Add('from vendas v');
        Sql.Add('where v.uuid = '+QuotedStr(_vendaUUID));
        Open;

        if IsEmpty then
             FinalizaProcesso('Venda Invalida');

        _tabelaPrecoID := FieldByName('tabela_preco_id').AsInteger;
        _armazenamentoID := FieldByName('armazenamento_id').AsInteger;



        if (_tabelaPrecoID = 0 ) then
           FinalizaProcesso('Tabela Preço não Informada');


        if (_armazenamentoID = 0 ) then
           FinalizaProcesso('Tabela Armazenamento não Informada');


        Close;
        Sql.Clear;
        Sql.Add(GetSqlProduto(_codigo,
                              IntToStr(_armazenamentoID),
                              IntToStr(_tabelaPrecoID),
                              sessao.gradeID
                             )

                );
        Open;

        if RecordCount > 1 then
        Begin
              sessao.getID := '';
              sessao.gradeID:= '';

              f_produtosPesquisaSelecao := tf_produtosPesquisaSelecao.Create(nil);
              f_produtosPesquisaSelecao.qItens.Close;
              f_produtosPesquisaSelecao.qItens.Open;
              first;

               while not eof do
               begin
                   f_produtosPesquisaSelecao.qItens.Append;
                   f_produtosPesquisaSelecao.qItensid.Value := _db.qrySelect.FieldByName('produto_id').AsInteger;
                   f_produtosPesquisaSelecao.qItensdescricao.Value:= _db.qrySelect.FieldByName('descricao').AsString;
                   f_produtosPesquisaSelecao.qItensgrade_id.Value:= _db.qrySelect.FieldByName('gradeamento_id').AsInteger;
                   f_produtosPesquisaSelecao.qItensn_marca.Value:= _db.qrySelect.FieldByName('n_marca').AsString;
                   f_produtosPesquisaSelecao.qItenssaldo.Value:= _db.qrySelect.FieldByName('saldo_gerencial').AsFloat;
                   f_produtosPesquisaSelecao.qItensun_medida.Value:= _db.qrySelect.FieldByName('medida_descricao').AsString;
                   f_produtosPesquisaSelecao.qItensvalor.Value:= _db.qrySelect.FieldByName('valor').AsFloat;
                   f_produtosPesquisaSelecao.qItens.Post;
                   Next;
               end;
               f_produtosPesquisaSelecao.StatusBar1.Panels[0].Text:='Registro(s) Encontrado(s): '+IntTostr(RecordCount);
               f_produtosPesquisaSelecao.qItens.First;
               f_produtosPesquisaSelecao.ShowModal;
               f_produtosPesquisaSelecao.Release;
               f_produtosPesquisaSelecao := nil;

              Close;
              Sql.Clear;
              Sql.Add(GetSqlProduto(sessao.getID,IntToStr(_armazenamentoID),IntToStr(_tabelaPrecoID),sessao.gradeID));
              Open;

              if trim(sessao.getID) = '' then
                 exit;
        end;

        if IsEmpty then
           FinalizaProcesso('Produto Invalido');

        if FieldByName('valor').AsFloat = 0 then
           FinalizaProcesso('produto sem preco definido');

        if (FieldByName('ativo').AsString='false') then
           FinalizaProcesso('produto esta inativo');

        if  Length(FieldByName('medida_descricao').AsString) < 2 then
           FinalizaProcesso('Unidade Medida informada Invalida');

        _Produto := _db.ToObjectString('',true);
        _Produto['valor_unitario'].AsNumber:= DecimalUnitario(_produto['valor'].AsNumber);
        _produto['quantidade'].AsNumber:= quantidade;
        _produto['uuid_venda'].AsString:= _vendaUUID;
        VendaGetItemRecalculo(_Produto);

        if quantidade <= 0 then
           FinalizaProcesso('Quantidade invalida');

        _db.InserirDados('venda_itens',_Produto);
        result := true;
        FreeAndNil(_produto);
      end;
   finally
       FreeAndNil(_db);
   end;
end;


end.

