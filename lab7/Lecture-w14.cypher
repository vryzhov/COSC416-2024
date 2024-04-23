match (m:Movie), (d:Diana)
// where not (d) -[:RATED] -> (m)
call{with m 
     match (u:User)- [r:RATED]-> (m) -[:IN_GENRE] ->(g:Genre) 
     return collect(DISTINCT g.name) as genres, 
           2*round(avg(r.rating),4) as avgUserRating2 // doubled
    }
call {with d
    match(d) -[r:RATED] ->(m:Validation)
      where r.rating > 3
     with m order by r.rating desc
    return m as  bestDianaMovie  limit 10   }
with m, avgUserRating2, bestDianaMovie, gds.similarity.cosine(m.node2vec, bestDianaMovie.node2vec) as similarity
with m  as m, m.imdbRating as imdbRating, avgUserRating2 as avgUserRating2, 
 round(avg(similarity),4) as avgSimilarity  order by avgSimilarity desc
with collect(id(m)) as recommendation
CALL {match(mt:Validation) return collect(ID(mt)) as validation }
with recommendation,  validation
return 
 size(recommendation) AS sizeof_rec ,
       size(validation)     AS sizeof_val, 
    ROUND(gds.similarity.jaccard(recommendation[0..9], validation),10) 
      AS quality_10,
    ROUND(gds.similarity.jaccard(recommendation[0..19], validation),4) 
      AS quality_20, 
    ROUND(gds.similarity.jaccard(recommendation[0..29], validation),4) 
      AS quality_30,
    ROUND(gds.similarity.jaccard(recommendation[0..39], validation),4) 
      AS quality_40,
    ROUND(gds.similarity.jaccard(recommendation[0..49], validation),4) 
      AS quality_50



match (m:Movie), (d:Diana)
call{with m 
     match (u:User)- [r:RATED]-> (m) -[:IN_GENRE] ->(g:Genre) 
     return collect(DISTINCT g.name) as genres, 
           2*round(avg(r.rating),4) as avgUserRating2 // doubled
    }
with m, genres, avgUserRating2,
     round(gds.similarity.cosine(m.node2vec, d.node2vecAverageTrain),4)
           as similarity 
order by similarity desc
with collect(id(m)) as recommendation 
CALL {match(mt:Validation) return collect(ID(mt)) as validation }
with  recommendation, validation
RETURN size(recommendation) AS sizeof_rec ,
       size(validation)     AS sizeof_val, 
    ROUND(gds.similarity.jaccard(recommendation[0..9], validation),10) 
      AS quality_10,
    ROUND(gds.similarity.jaccard(recommendation[0..19], validation),4) 
      AS quality_20, 
    ROUND(gds.similarity.jaccard(recommendation[0..29], validation),4) 
      AS quality_30,
    ROUND(gds.similarity.jaccard(recommendation[0..39], validation),4) 
      AS quality_40,
    ROUND(gds.similarity.jaccard(recommendation[0..49], validation),4) 
      AS quality_50


match(m) 
return m.title limit 10




