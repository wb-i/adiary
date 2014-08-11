use strict;
#------------------------------------------------------------------------------
# データエクスポート for adiary(xml)
#                                                   (C)2013 nabe / nabe@abk
#------------------------------------------------------------------------------
package SatsukiApp::adiary::Export_adiary;
###############################################################################
# ■基本処理
###############################################################################
#------------------------------------------------------------------------------
# ●【コンストラクタ】
#------------------------------------------------------------------------------
sub new {
	my $self = bless({}, shift);
	$self->{ROBJ} = shift;

	return $self;
}

###############################################################################
# ■データエクスポート
###############################################################################
#------------------------------------------------------------------------------
# ●adiary形式のデータエクスポート
#------------------------------------------------------------------------------
sub export {
	my ($self, $skeleton, $logs, $option) = @_;
	my $ROBJ = $self->{ROBJ};
	my $aobj = $option->{aobj};

	# 文字コード変換
	my $system_coding = $ROBJ->{System_coding};
	my $output_coding = 'UTF-8';
	my $jcode = $system_coding ne $output_coding ? $ROBJ->load_codepm() : undef;

	# オプション
	my @pkey2tm;
	my $key2tm = $option->{key2tm};
	if ($key2tm) {
		foreach (@$logs) {
			$pkey2tm[ $_->{pkey} ] = $_->{tm};
		}
		# ※エクスポートするログの中に対象記事がなければ書き換えない
	}
	my $id2link = $option->{id2link};
	my $parser;
	if ($key2tm || $id2link) {
		$parser = $aobj->load_parser('default');
	}

	#---------------------------------------------------------------------
	# ログの解析と保存
	#---------------------------------------------------------------------
	foreach (@$logs) {
		#-------------------------------------------------------------
		# 日付の加工
		#-------------------------------------------------------------
		{
			my $yyyymmdd = $_->{yyyymmdd};
			$_->{year} = substr($yyyymmdd, 0, 4);
			$_->{mon}  = substr($yyyymmdd, 4, 2);
			$_->{day}  = substr($yyyymmdd, 6, 2);
		}
		#-------------------------------------------------------------
		# 本文の加工（記事番号指定 → 記事時刻指定）
		#-------------------------------------------------------------
		if ($_->{parser} =~ /^default/ &&
		   ($key2tm && $_->{_text} =~ /\[key:/ || $id2link && $_->{_text} =~ /\[id:/)) {
			my $backup = $parser->backup_blocks($_->{_text});

			# key指定をtm指定に変更
			if ($key2tm) {
				$_->{_text} =~ s/\[key:(\d+)([\]:])/
					'[key:' . ($pkey2tm[$1] || $1) . $2/eg;
			}

			# id 指定を通常リンクに書き換え（パーサーに通す）
			if ($id2link) {
				$_->{_text} =~ s!(\[id:[^\]]+\])!
					my $link = $parser->parse_tag( $1 );
					$parser->un_escape( $link );
					$link;
				!eg;
			}

			# 戻す
			$parser->restore_blocks($_->{_text}, $backup);
		}

		#-------------------------------------------------------------
		# スケルトンの実行
		#-------------------------------------------------------------
		my $day = $ROBJ->exec( $skeleton, $_ );

		#-------------------------------------------------------------
		# 出力
		#-------------------------------------------------------------
		my $str = $ROBJ->chain_array( $day );
		if ($jcode) {
			$jcode->from_to(\$str, $system_coding, $output_coding);
		}
		print $str;
	}
	return 0;
}

1;
