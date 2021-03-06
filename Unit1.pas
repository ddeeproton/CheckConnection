unit Unit1;

interface

uses
  Windows, Messages, SysUtils, Classes, Graphics, Controls, Forms,
  Dialogs, ExtCtrls, StdCtrls, IdBaseComponent, IdComponent, IdRawBase,
  IdRawClient, IdIcmpClient;


type
  TForm1 = class(TForm)
    LabelTitre: TLabel;
    ImageOrdinateur: TImage;
    Cable_OrdinateurModem: TLabel;
    ImageInternet: TImage;
    ImageModem: TImage;
    Cable_ModemInternet: TLabel;
    Label4: TLabel;
    Label5: TLabel;
    Label6: TLabel;
    Memo1: TMemo;
    ICMP: TIdIcmpClient;
    TimerPing: TTimer;
    TimerAnimation: TTimer;
    Procedure MessageErreure();
    procedure ChangeCouleur(Etat:Boolean);
    procedure TimerPingTimer(Sender: TObject);
    procedure LabelTitreClick(Sender: TObject);
    procedure ICMPReply(ASender: TComponent; const AReplyStatus: TReplyStatus);
    procedure TimerAnimationTimer(Sender: TObject);
    procedure FormCreate(Sender: TObject);
    procedure FormResize(Sender: TObject);
  private
    { Private declarations }
  public
    { Public declarations }
  end;


var
  Form1: TForm1;
  Noms: array[1..2] of string = ('le modem', 'Internet');
  AdressesIP: array[1..2] of string;
  AdresseActuelle: integer = 1;
  FichiersMessagesErreures: array[1..2] of string = ('Prob du PC jusqu''au Modem.txt', 'Prob du Modem jusqu''� Internet.txt');
implementation

{$R *.dfm}
uses WinSock;


// Donne l'ip de la premi�re Interface r�seau trouv� (tout comme ipconfig.exe de windows)
function IPconfig():string;
var
  wVersionRequested : WORD;
  wsaData : TWSAData;
  s : array[0..128] of char;
  p : PHostEnt;
  p2 : pchar;
  OutPut :array[0..100] of char;
begin
  {D�marrer WinSock}
  wVersionRequested := MAKEWORD(1, 1);
  WSAStartup(wVersionRequested, wsaData);
  {R�cup�rer l'adresse Ip}
  GetHostName(@s, 128);
  p := GetHostByName(@s);
  p2 := iNet_ntoa(PInAddr(p^.h_addr_list^)^);
  StrPCopy(OutPut,Format('%s',[p2]));
  WSACleanup;
  result := OutPut;
end;


// Transforme la derni�re partie d'un IP en '1' ( 192.168.0.64 sera 192.168.0.1 )
// ceci dans le but de trouver le modem et l'int�rroger.
function IPduModem(ip:string):string;
var
  i: integer;
  ipModem: string;
begin
  ipModem := '';
  for i:=length(ip) downto 1 do
  begin
    if (ipModem = '') and (ip[i] = '.')
    or (ipModem <> '') then
      ipModem := ip[i] + ipModem;
  end;
  result := ipModem+'1';
end;


procedure TForm1.FormCreate(Sender: TObject);
begin
  Memo1.Clear;
  // Pour �viter d'�crire les choses deux fois, j'ai utilis� des tableaux
  // On ping en premier le modem et ensuite sur Internet
  AdressesIP[1] := IPduModem(IPconfig);   // ip du modem
  AdressesIP[2] := 'iana.org';         //  ping iana.org
  // Conseil: Mettre si possible une addresse ip au lieu d'un nom de domaine www
  // ceci pour �viter des messages d'erreures lorsque celui-ci ne r�pond pas.
end;


// Messages d'erreurs
Procedure TForm1.MessageErreure();
begin
  ChangeCouleur(False); // Affiche en rouge la non connection
  LabelTitre.Caption := 'Probleme avec '+Unit1.Noms[Unit1.AdresseActuelle]+'  (cliquez ici pour tester � nouveau)';
  Memo1.Lines.LoadFromFile(ExtractFileDir(Application.Exename)+'\Messages d''erreures\'+FichiersMessagesErreures[AdresseActuelle]);
end;


// Affecte la couleur aux fils (vert ou rouge)
procedure TForm1.ChangeCouleur(Etat:Boolean);
var
  couleurs: Tcolor;
begin
 if Etat then couleurs := clLime // vert
 else         couleurs := clRed; // rouge
 // Affecte la couleur aux fils
 Cable_OrdinateurModem.Color := couleurs;
 if AdresseActuelle = 2 then
   Cable_ModemInternet.Color := couleurs;
end;


// Effectue un ping
procedure TForm1.TimerPingTimer(Sender: TObject);
begin
  TimerPing.Enabled := false;
  ICMP.ReceiveTimeout := 3000;
  try
    ICMP.Host := AdressesIP[AdresseActuelle];
    ICMP.Ping;
    Application.ProcessMessages;
  Except
    on E: Exception do
    Begin
    TimerAnimation.Enabled := False;
    //pour connaitre le texte du message d'erreur activer la ligne suivante
    //ShowMessage(E.Message);
    MessageErreure;
    End;
  end;
end;


// Si on clique n'importe o� sur la fen�tre
procedure TForm1.LabelTitreClick(Sender: TObject);
begin
  Memo1.Clear;
  // On ferme si le test � �t� fait et r�ussi
  if LabelTitre.Caption = 'Test r�ussi! :) ' then
    Application.Terminate;
  // S'il n'y a pas d'interface r�seau activ�
  if  AdressesIP[1] = '127.0.0.1' then
  begin
    MessageErreure;
    exit;
  end;
  // Si on recommence le test suite � un �chec, on remet � z�ro
  AdresseActuelle := 1;
  LabelTitre.caption := 'Test en cours...';
  // On lance une animation en attendant la r�ponse du ping
  TimerAnimation.Enabled := true;
  // Lance le ping
  TimerPing.Enabled := true;
end;


// On re�oit le r�sultat du ping ici
procedure TForm1.ICMPReply(ASender: TComponent; const AReplyStatus: TReplyStatus);
var
  TempsDeReponse: integer;
begin
  TempsDeReponse := AReplyStatus.MsRoundTripTime;
  // On arr�te l'animation du fil pour lui donner sa couleur verte ou rouge
  TimerAnimation.Enabled := False;
  ChangeCouleur(TempsDeReponse < 2500); // Affecte la couleur rouge ou verte au fil
  // Si on a r�pondu avant 2.5 secondes
  if TempsDeReponse < 2500 then
    Memo1.Lines.Add(Noms[AdresseActuelle]+' est ok ')
  else
  begin //Ping n'a pas r�pondu � temps
    // Si l'adresse IP est diff�rente de 127.0.0.1,
    // �a veux dire qu'il y a tout de m�me un r�seau, alors on continue les tests
    if (AdressesIP[1] <> '127.0.0.1') and (AdresseActuelle = 1) then
      Cable_OrdinateurModem.Color := clGray // On met un gris vu que la connection au modem est incertaine
    else begin
      MessageErreure();
      Exit;
    end;
  end;
  // Si on n'est pas encore au dernier test
  if AdresseActuelle < 2 then
  begin
    // Passe au test suivant
    inc(AdresseActuelle);
    // Lance le ping
    TimerPing.Enabled := True;
    // D�marre l'animation du fil en attendant la r�ponse du ping
    TimerAnimation.Enabled := True;
  end
  else begin // On est arriv� au dernier test
    LabelTitre.Caption := 'Test r�ussi! :) ';
    Memo1.Lines.Add('Tout fonctionne :)');
    Memo1.Lines.Add('Cliquer ici pour fermer.');
  end;
end;


// Animation du fil en attendant une r�ponse du modem
procedure TForm1.TimerAnimationTimer(Sender: TObject);
var
  couleur: TColor;
begin
  // Alternance entre noir et gris
  if Cable_ModemInternet.Color = clBlack then
    couleur := clGray
  else
    couleur := clBlack;
  // On donne la couleur aux c�bles
  if AdresseActuelle = 1 then
    Cable_OrdinateurModem.Color := couleur;  // fil du modem
  Cable_ModemInternet.Color := couleur; // fil Internet
end;



procedure TForm1.FormResize(Sender: TObject);
begin
  Cable_OrdinateurModem.Width := ImageModem.Left - Cable_OrdinateurModem.Left + 5;
  Cable_ModemInternet.Left    := ImageModem.Left + ImageModem.Width - 5;
  Cable_ModemInternet.Width   := ImageInternet.Left - Cable_ModemInternet.Left + 5;
end;

end.
