Logos.define LegacyResolvedDuplicateToken do
  regex "a", :A
  regex "[a]", :A
end

Logos.define LegacyResolvedDistinctToken do
  regex "a", :First, priority: 5
  regex "[a]", :Second, priority: 9
end

Logos.define GenericManifestPriorityToken do
  skip_regex ".", :Ignored
  regex "a", :A
end

Logos.define DeferredSkipTieToken do
  skip_regex "a", :Ignored
  regex "[a]", :A
end

Logos.define ResolvedShadowedToken do
  regex "a", :Low
  regex "[a]", :Low
  regex "[a-a]", :High, priority: 4
end

{LegacyResolvedDuplicateToken, LegacyResolvedDistinctToken, GenericManifestPriorityToken, ResolvedShadowedToken, DeferredSkipTieToken}.each do |token_type|
  raise "matcher did not register for #{token_type}" unless token_type.precompiled_dfa?
end

begin
  LegacyResolvedDuplicateToken.lexer("a").next
  raise "resolved matcher concealed a duplicate variant"
rescue ex
  raise ex unless ex.message.try(&.includes?("can match simultaneously"))
end

legacy = LegacyResolvedDistinctToken.lexer("a").spanned.to_a
raise "legacy resolved fallback changed: #{legacy.inspect}" unless legacy == [
                                                                     {Logos::Result(LegacyResolvedDistinctToken, Nil).ok(LegacyResolvedDistinctToken::First), 0...1},
                                                                   ]

generic = GenericManifestPriorityToken.lexer("xa").spanned.to_a
raise "generic manifest priority was ignored: #{generic.inspect}" unless generic == [
                                                                           {Logos::Result(GenericManifestPriorityToken, Nil).ok(GenericManifestPriorityToken::A), 1...2},
                                                                         ]

shadowed = ResolvedShadowedToken.lexer("a").spanned.to_a
raise "resolved matcher did not select the higher rule: #{shadowed.inspect}" unless shadowed == [
                                                                                      {Logos::Result(ResolvedShadowedToken, Nil).ok(ResolvedShadowedToken::High), 0...1},
                                                                                    ]

begin
  DeferredSkipTieToken.lexer("a").next
  raise "generic matcher ignored explicit skip tie metadata"
rescue ex
  raise ex unless ex.message.try(&.includes?("can match simultaneously"))
end
