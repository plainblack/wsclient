package WebGUI::Wobject::WSClient;

use strict;
use Data::Dumper;
use Digest::MD5;
use SOAP::Lite;
use Storable;
use WebGUI::Cache;
use WebGUI::ErrorHandler;
use WebGUI::HTMLForm;
use WebGUI::International;
use WebGUI::Macro;
use WebGUI::Paginator;
use WebGUI::Privilege;
use WebGUI::Session;
use WebGUI::Wobject;

my ($hasUnblessAcme, $hasUnblessData, $hasUtf8, $utf8FieldType);

# we really would like to be able to unbless references and strip utf8 data,
# but that requires non-standard and possibly difficult to install modules
BEGIN {

   # check for Data::Structure::Util, which requires perl 5.8.0 :-P
   eval { require Data::Structure::Util; };
   if ($@) {

      $utf8FieldType = 'hidden';

      # try Acme::Damn as partial fallback
      eval { require Acme::Damn; };
      $hasUnblessAcme = 1 if !$@;

   } else {

      $utf8FieldType = 'yesNo';
      $hasUnblessData = 1;
      $hasUtf8        = 1 if $] >= 5.008;
   }
}

our @ISA = qw(WebGUI::Wobject);


#-------------------------------------------------------------------
sub name {
   return WebGUI::International::get(1, $_[0]->get('namespace'));
}

#-------------------------------------------------------------------
sub new {
   my ($self, $class, $httpHeaderFieldType, $property);

   $class = shift;
   $property = shift;

   # specify in the config file if you want to force diff http headers, 
   # for outputting raw pdfs, etc
   if ($session{'config'}{'soapHttpHeaderOverride'}) {
      $httpHeaderFieldType = 'text';
   } else {
      $httpHeaderFieldType = 'hidden';
   }

   $self = WebGUI::Wobject->new(
      -properties         => $property,
      -extendedProperties => {
         call             => {
            fieldType     => 'textarea',
         },
         debugMode        => {
            fieldType     => 'integer',
            defaultValue  => 0,
         },
         execute_by_default => {
            fieldType     => 'yesNo',
            defaultValue  => 1,
         },
         paginateAfter    => {
            defaultValue  => 100,
         },
         paginateVar    => {
            fieldType     => 'text',
         },
         params           => {
            fieldType     => 'textarea',
         },
         preprocessMacros => {
            fieldType     => 'integer',
            defaultValue  => 0,
         },
         proxy            => {
            fieldType     => 'text',
            defaultValue  => $session{'config'}{'soapproxy'},
         },
         templateId       => {
            defaultValue  => 1,
         },
         uri              => {
            fieldType     => 'text',
            defaultValue  => $session{'config'}{'soapuri'}
         },
         decodeUtf8       => {
            fieldType     => $utf8FieldType,
            defaultValue  => 0,
         },
         httpHeader       => {
            fieldType     => $httpHeaderFieldType,
         },
         cacheTTL         => {
            fieldType     => 'integer',
            defaultValue  => 60,
         },
      },
   );
   bless $self, $class;
}


#-------------------------------------------------------------------
sub www_edit {
   return WebGUI::Privilege::insufficient()
      unless WebGUI::Privilege::canEditPage();

   my $layout     = WebGUI::HTMLForm->new;
   my $privileges = WebGUI::HTMLForm->new;
   my $properties = WebGUI::HTMLForm->new;

   # "Layout" tab
   $layout->template(
      -name      => 'templateId',
      -value     => $_[0]->getValue('templateId'),
      -namespace => $_[0]->get('namespace'),
   );
   $layout->yesNo (
      -name  => 'preprocessMacros',
      -label => WebGUI::International::get(8, $_[0]->get('namespace')),
      -value => $_[0]->get('preprocessMacros'),
   );
   $layout->integer(
      -name  => 'paginateAfter',
      -label => WebGUI::International::get(13, $_[0]->get('namespace')),
      -value => $_[0]->getValue("paginateAfter")
   );
   $layout->text (
      -name  => 'paginateVar',
      -label => WebGUI::International::get(14, $_[0]->get('namespace')),
      -value => $_[0]->get('paginateVar'),
   );

   # "Properties" tab
   $properties->text (
      -name  => 'uri',
      -label => WebGUI::International::get(2, $_[0]->get('namespace')),
      -value => $_[0]->get('uri'),
   );
   $properties->text (
      -name  => 'proxy',
      -label => WebGUI::International::get(3, $_[0]->get('namespace')),
      -value => $_[0]->get('proxy'),
   );
   $properties->text (
      -name  => 'call',
      -label => WebGUI::International::get(4, $_[0]->get('namespace')),
      -value => $_[0]->get('call'),
   );
   $properties->textarea ( 
      -name  => 'params',
      -label => WebGUI::International::get(5, $_[0]->get('namespace')),
      -value => $_[0]->get('params'),
   );

   if ($session{'config'}{'soapHttpHeaderOverride'}) {
      $properties->text (
         -name  => 'httpHeader',
         -label => WebGUI::International::get(16, $_[0]->get('namespace')),
         -value => $_[0]->get('httpHeader'),
      );
   } else {
      $properties->hidden (
         -name  => 'httpHeader',
         -label => WebGUI::International::get(16, $_[0]->get('namespace')),
         -value => $_[0]->get('httpHeader'),
      );
   }

   $properties->yesNo (
      -name  => 'execute_by_default',
      -label => WebGUI::International::get(11, $_[0]->get('namespace')),
      -value => $_[0]->get('execute_by_default'),
   );
   $properties->yesNo (
      -name  => 'debugMode',
      -label => WebGUI::International::get(9, $_[0]->get('namespace')),
      -value => $_[0]->get('debugMode'),
   );

   if ($utf8FieldType eq 'yesNo') {
      $properties->yesNo (
         -name  => 'decodeUtf8',
         -label => WebGUI::International::get(15, $_[0]->get('namespace')),
         -value => $_[0]->get('decodeUtf8'),
      );
   } else {
      $properties->hidden (
         -name  => 'decodeUtf8',
         -label => WebGUI::International::get(15, $_[0]->get('namespace')),
         -value => $_[0]->get('decodeUtf8'),
      );
   }

   $properties->text (
      -name     => 'cacheTTL',
      -label    => WebGUI::International::get(27, $_[0]->get('namespace')),
      -value    => $_[0]->get('cacheTTL'),
   );

   return $_[0]->SUPER::www_edit (
      -layout     => $layout->printRowsOnly,
      -privileges => $privileges->printRowsOnly,
      -properties => $properties->printRowsOnly,
      -headingId  => 20,
      -helpId     => 1,
   );
}

#-------------------------------------------------------------------
sub www_view {
   my ( $arr_ref,                      # temp var holding params
        $cache_key,                    # unique cache identifier
        $cache,                        # cache object
        $call,                         # SOAP method call
        $p,                            # pagination object
        $param_str,                    # raw SOAP params before parsing
        @params,                       # params to soap method call
        @result,                       # SOAP result reference
        $soap,                         # SOAP object
        @targetWobjects,               # list of non-default wobjects to exec
        $url,                          # current page url
        %var                          # HTML::Template variables
   );
   my $self= shift;

   # this page, with important params
   $url = WebGUI::URL::page("func=view&wid=" . $self->get("wobjectId"));

   # snag our SOAP call and preprocess if needed
   $call        = WebGUI::Macro::process($self->get('call'));
   $param_str   = WebGUI::Macro::process($self->get('params'));
   if ($self->get('preprocessMacros')) {
      WebGUI::Macro::process($call);
      WebGUI::Macro::process($param_str);
   }

   # advanced use, if you want to pass SOAP results to a single, particular
   # wobject on a page
   if (ref $session{'form'}{'targetWobjects'}) {
      @targetWobjects = @{$session{'form'}{'targetWobjects'}};
   } else {
      push @targetWobjects, $session{'form'}{'targetWobjects'};
   }

   # check to see if this exact query has already been cached
   $cache_key = $session{'form'}{'cache'} ||
      Digest::MD5::md5_hex($call, $param_str);
   $cache = WebGUI::Cache->new($cache_key,
      WebGUI::International::get(4, $self->get('namespace')));
   @result = Storable::thaw($cache->get);
   
   # prep SOAP unless we found cached data
   if (!$result[0]) {
      # this is the magic right here.  We're allowing perl to parse out 
      # the ArrayOfHash info so that we don't have to regex it ourselves
      # FIXME:  we need to protect against eval-ing unknown strings
      # the solution is to normalize all params to another table
      eval "\$arr_ref = [$param_str];";
      eval { @params = @$arr_ref; };
      WebGUI::ErrorHandler::warn(WebGUI::International::get(22,
         $self->get('namespace'))) if $@ && $self->get('debugMode');

      if ($self->get('execute_by_default') || grep /^$call$/,
         @targetWobjects) {

         # there's certainly a better pattern match than this to check for 
         # valid looking uri, but I haven't hunted for the relevant RFC yet
         if ($self->get("uri") =~ m!.+/.+!) {

            WebGUI::ErrorHandler::warn('uri=' . $self->get("uri"))
               if $self->get('debugMode');
            $soap = $self->_instantiate_soap;

         } else {
            WebGUI::ErrorHandler::warn(WebGUI::International::get(23,
               $self->get('namespace'))) if $self->get('debugMode');
         }
      }
   }

   # continue if our SOAP connection was successful or we have cached data
   if (defined $soap || $result[0]) {

      if (!$result[0]) {
         eval {
            # here's the rub.  `perldoc SOAP::Lite` says, "the method in
            # question will return the current object (if not stated
            # otherwise)".  That "not stated otherwise" bit is important.
            my $return = $soap->$call(@params);
         
            WebGUI::ErrorHandler::warn("$call(" . (join ',', @params) . ')')
               if $self->get('debugMode');

            # The possible return types I've come across include a SOAP object,
            # a hash reference, a blessed object or a simple scalar.  Each type
            # requires different handling (woohoo!) before being passed to the
            # template system
            WebGUI::ErrorHandler::warn(WebGUI::International::get(24,
               $self->get('namespace')) .
               (ref $return ? ref $return : 'scalar'))
               if $self->get('debugMode');

            # SOAP object
            if ((ref $return) =~ /SOAP/i) {
               @result = $return->paramsall;

            # hashref
            } elsif (ref $return eq 'HASH') {
               @result = $return;

            # blessed object, to be stripped with Acme::Damn
            } elsif ($hasUnblessAcme && ref $return) {
               WebGUI::ErrorHandler::warn("Acme::Damn::unbless($return)");
               @result = Acme::Damn::unbless($return);

            # blessed object, to be stripped with Data::Structure::Util
            } elsif ($hasUnblessData && ref $return) {
               WebGUI::ErrorHandler::warn("Data::Structure::Util::unbless($return)");
               @result = Data::Structure::Util::unbless($return);

            # scalar value, we hope
            } else {
               # there's got to be a way to get into the SOAP body and find the
               # key name for the value returned, but I haven't figured it out
               @result = { 'result' => $return };
            }

            $cache->set(Storable::freeze(@result),
               $wobject[0]->get('cacheTTL'));
         };

         # did the soap call fault?
         if ($@) {
            WebGUI::ErrorHandler::warn($@) if $self->get('debugMode');
            $var{'soapError'} = $@;
            WebGUI::ErrorHandler::warn(WebGUI::International::get(25,
               $self->get('namespace')) . $var{'soapError'})
               if $self->get('debugMode');
         }

      # cached data was found
      } else {
         WebGUI::ErrorHandler::warn("Using cached data");
      }

        WebGUI::ErrorHandler::warn(Dumper(@result)) if     
           $self->get('debugMode');

      # Do we need to decode utf8 data?  Will only decode if modules were
      # loaded and the wobject requests it
      if ($self->{'decodeUtf8'} && $hasUtf8) {
         if (Data::Structure::Util::has_utf8(\@result)) {
            @result = @{Data::Structure::Util::utf8_off(\@result)};
         }
      }

      # pagination is tricky because we don't know the specific portion of the
      # data we need to paginate.  Trust the user to have told us the right 
      # thing.  If not, try to Do The Right Thing
      if (scalar @result > 1) {
         # this case hasn't ever happened running against my dev SOAP::Lite
         # services, but let's assume it might.  If our results array has
         # more than one element, let's hope if contains scalars
         $p = WebGUI::Paginator->new($url, $self->get('paginateAfter'));
	$p->setDataByArrayRef(\@result);
         @result = ();
         @result = @$p;

      } else {

         # In my experience, the most common case.  We have an array
         # containing a single hashref for which we have been given a key name
         if (my $aref = $result[0]->{$self->get('paginateVar')}) {

            $var{'numResults'} = scalar @$aref;
            $p = WebGUI::Paginator->new($url,  $self->get('paginateAfter'));
		$p->setDataByArrayRef($aref);
            $result[0]->{$self->get('paginateVar')} = $p->getPageData;

         } else {

            if ((ref $result[0]) =~ /HASH/) {

               # this may not paginate the one that they want, but it will
               # prevent the wobject from dying
               for (keys %{$result[0]}) {
                  if ((ref $result[0]->{$_}) =~ /ARRAY/) {
                       $p = WebGUI::Paginator->new($url,  $self->get('paginateAfter'));
			$p->setDataByArrayRef($result[0]->{$_});
                     last;
                  }
               }
               $p ||= WebGUI::Paginator->new($url);
               $result[0]->{$_} = $p->getPageData;
               
            } elsif ((ref $result[0]) =~ /ARRAY/) {
               $p = WebGUI::Paginator->new($url, $self->get('paginateAfter'));
		$p->setDataByArrayRef($result[0]);
               $result[0] = $p->getPageData;

            } else {
               $p = WebGUI::Paginator->new($url, $self->get('paginateAfter'));
		$p->setDataByArrayRef([$result[0]]);
               $result[0] = $p->getPageData;
            }
         }
      }

      # set pagination links
      if ($p) {
	$p->appendTemplateVars(\%var);
         for ('pagination.firstPage','pagination.lastPage','pagination.nextPage','pagination.pageList',
		'pagination.previousPage', 'pagination.pageList.upTo20', 'pagination.pageList.upTo10') {
            $var{$_} =~ s/\?/\?cache=$cache_key\&/g;
         }
      }


   } else {
      WebGUI::ErrorHandler::warn(WebGUI::International::get(26,
         $self->get('namespace')) . $@) if $self->get('debugMode');
   }

   # did they request a funky http header?
   if ($session{'config'}{'soapHttpHeaderOverride'} &&
      $self->get("httpHeader")) {

      $session{'header'}{'mimetype'} = $self->get("httpHeader");
      WebGUI::ErrorHandler::warn("changed mimetype: " . 
         $session{'header'}{'mimetype'});
   }

   # Note, we still process our template below even though it will never
   # be displayed if the redirectURL is set.  Not sure how important it is
   # to do it this way, but it certainly is the least obtrusive to default
   # webgui flow.  This feature currently requires a patched WebGUI.pm file.
   if ($session{'form'}{'redirectURL'}) {
      $session{'page'}{'redirectURL'} = $session{'form'}{'redirectURL'};
   }

   $var{'results'} = \@result;
   return $self->processTemplate($self->get("templateId"),\%var);
}   


sub _instantiate_soap {
   my ($soap, @wobject);
   my $self = shift;

   # a wsdl file was specified
   # we don't use fault handling with wsdls becuase they seem to behave 
   # differently.  Not sure if that is by design.
   if ($self->get("uri") =~ m/\.wsdl\s*$/i) {

      WebGUI::ErrorHandler::warn('wsdl=' . $self->get('uri'))
         if $self->get('debugMode');

      # instantiate SOAP service
      $soap = SOAP::Lite->service($self->get('uri'));
                                                                                
   # standard uri namespace
   } else {
      WebGUI::ErrorHandler::warn('uri=' . $self->get('uri'))
         if $self->get('debugMode');

      # instantiate SOAP service, with fault handling
      $soap = new SOAP::Lite     
         on_fault => sub {    
            my ($soap, $res) = @_;     
            die $res->faultstring;     
         };
      $soap->uri($self->get('uri'));
                                                                                
      # proxy the call if requested
      if ($self->get("proxy") && $soap) {

         WebGUI::ErrorHandler::warn('proxy=' . $self->get('proxy'))
            if $self->get('debugMode');
         $soap->proxy($self->get('proxy'));
      }
   }

   return $soap;
}
1;
